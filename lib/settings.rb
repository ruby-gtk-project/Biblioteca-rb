# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'gio2'

require_relative 'package'

# Settings is the application's five settings keys: color-scheme,
# window-width, window-height, window-maximized and window-fullscreened.
#
# Ported from upstream's data/app.gschema.xml, which src/util.js:4 opens as a
# Gio.Settings. The schema this port ships is that file with @app_id@
# substituted (data/app.gschema.xml), and the keys, types and defaults are
# upstream's unchanged.
#
# Gio::Settings is the backend whenever the compiled schema can be found: in a
# system install, or in a checkout that has run `rake schema:compile`, which
# writes data/schemas/gschemas.compiled. That is the only backend with the
# behaviour upstream depends on — `gsettings` and dconf-editor can read and
# write the keys, an installed copy's values are picked up, and a
# `changed::color-scheme` emitted by another process reaches this one.
#
# When no compiled schema can be found at all, Settings falls back to a JSON
# file under XDG_CONFIG_HOME so that a fresh checkout runs before it installs
# anything. That fallback is strictly worse and is documented as such:
#
#   * it is per-process. Two running copies do not see each other's writes, so
#     a color-scheme change in one does not reach the other, where upstream's
#     `changed::color-scheme` (src/application.js:28) is cross-process.
#   * `gsettings get org.rubygtkproject.Biblioteca color-scheme` cannot see it.
#   * it does not migrate: values written by the JSON fallback are not read
#     back once the schema is installed.
#
# #using_gsettings? says which backend is live, and #location says where the
# values are, so a bug report can tell the two apart.
class Settings
  # The schema's keys, with their GVariant type codes and upstream's defaults
  # (data/app.gschema.xml). The type code decides which Gio::Settings accessor
  # is used, because Gio::Settings#[] returns a GLib::Variant rather than a
  # Ruby value.
  KEYS = {
    'color-scheme'        => ['i', 0],
    'window-width'        => ['i', 0],
    'window-height'       => ['i', 0],
    'window-maximized'    => ['b', false],
    'window-fullscreened' => ['b', false],
  }.freeze

  DEFAULTS = KEYS.transform_values(&:last).freeze

  def initialize(path: nil, schema_id: Package.schema_id, schema_dirs: nil)
    @schema_id = schema_id
    @schema_dirs = schema_dirs || [Package.schema_dir]
    @path = path || default_path
    @gio = lookup_gsettings
    unless @gio
      @values = DEFAULTS.merge(read)
      @watchers = {}
    end
  end

  def using_gsettings? = !@gio.nil?

  def location
    if @gio
      "gsettings:#{@schema_id}#{Package.schema_path}"
    else
      @path
    end
  end

  def [](key)
    key.to_s.then do |name|
      if @gio
        read_gio(name)
      else
        @values.fetch(name, DEFAULTS[name])
      end
    end
  end

  def []=(key, value)
    key.to_s.then do |name|
      if @gio
        write_gio(name, value)
      else
        write_json(name, value)
      end
      value
    end
  end

  # Named accessors for every key, so callers do not repeat the strings:
  # `settings.color_scheme`, `settings.window_width = 1080`.
  KEYS.each_key do |key|
    method_name = key.tr('-', '_')
    define_method(method_name) { self[key] }
    define_method(:"#{method_name}=") { |value| self[key] = value }
    if DEFAULTS[key] == false
      define_method(:"#{method_name}?") { self[key] == true }
    end
  end

  # Upstream's `settings.connect("changed::color-scheme", setColorScheme)`
  # (src/application.js:28).
  def on_changed(key, &block)
    key.to_s.then do |name|
      if @gio
        @gio.signal_connect("changed::#{name}") { block.call(self[name]) }
      else
        @watchers[name] ||= []
        @watchers[name] << block
      end
    end
  end

  # Upstream's `settings.bind(key, object, property, Gio.SettingsBindFlags.DEFAULT)`,
  # which persistWindowState uses for window-maximized and window-fullscreened
  # (troll/src/util.js). DEFAULT is two-way: the property is set from the key
  # now, and each side follows the other afterwards.
  def bind(key, object, property)
    key.to_s.then do |name|
      if @gio
        @gio.bind(
          name,
          object,
          property,
          :default,
        )
      else
        bind_json(name, object, property)
      end
    end
  end

  # Upstream's `settings.create_action("color-scheme")` (src/actions.js), the
  # stateful action the theme selector's three check buttons target.
  def color_scheme_action
    @color_scheme_action ||= build_color_scheme_action
  end

  private

    def build_color_scheme_action
      if @gio
        @gio.create_action('color-scheme')
      else
        json_color_scheme_action
      end
    end

    # The compiled schema, from the system's default source first — so an
    # installed copy wins — and then from any directory this port compiled one
    # into itself. nil when there is no compiled schema anywhere, which is the
    # one case the JSON fallback exists for.
    def lookup_gsettings
      schema_source.then do |source|
        source&.lookup(@schema_id, true).then do |schema|
          if schema
            Gio::Settings.new(schema: schema, path: Package.schema_path)
          end
        end
      end
    rescue GLib::Error, NoMethodError
      nil
    end

    def schema_source
      Gio::SettingsSchemaSource.default.then do |default_source|
        @schema_dirs.select { |dir| File.exist?(File.join(dir, 'gschemas.compiled')) }
                    .inject(default_source) do |parent, dir|
                      Gio::SettingsSchemaSource.new(dir, parent, true)
                    end
      end
    end

    def read_gio(name)
      case KEYS.fetch(name, ['i']).first
      when 'b' then @gio.get_boolean(name)
      else @gio.get_int(name)
      end
    end

    def write_gio(name, value)
      case KEYS.fetch(name, ['i']).first
      when 'b' then @gio.set_boolean(name, value ? true : false)
      else @gio.set_int(name, value.to_i)
      end
    end

    def write_json(name, value)
      @values[name] = value
      write
      @watchers.fetch(name, []).each { |block| block.call(value) }
    end

    # The JSON fallback's stand-in for Gio::SettingsBindFlags::DEFAULT: seed
    # the property from the stored value, then keep both directions in step.
    # Writing a property the value it already holds emits nothing, so the two
    # handlers settle rather than loop.
    def bind_json(name, object, property)
      object.set_property(property, self[name])
      object.signal_connect("notify::#{property.tr('_', '-')}") do
        write_json(name, object.get_property(property))
      end
      @watchers[name] ||= []
      @watchers[name] << ->(value) { object.set_property(property, value) }
    end

    # The JSON fallback's stand-in for Gio::Settings#create_action.
    #
    # The variant type has to be spelled out. GLib::Variant.new(0) with no type
    # builds an int64, and the schema key — along with every action target the
    # theme selector sets — is an int32.
    def json_color_scheme_action
      Gio::SimpleAction.new(
        'color-scheme',
        GLib::VariantType.new('i'),
        GLib::Variant.new(self['color-scheme'], 'i'),
      ).tap do |action|
        # ruby-gnome hands the action parameter over already unwrapped, so this
        # is a Ruby Integer rather than a GLib::Variant.
        action.signal_connect('activate') do |_, parameter|
          action.set_state(GLib::Variant.new(parameter.to_i, 'i'))
          self['color-scheme'] = parameter.to_i
        end
      end
    end

    def default_path
      File.join(
        ENV.fetch('XDG_CONFIG_HOME', File.expand_path('~/.config')),
        'biblioteca-rb',
        'settings.json',
      )
    end

    def read
      if File.exist?(@path)
        JSON.parse(File.read(@path))
      else
        {}
      end
    rescue JSON::ParserError => e
      warn "Error parsing #{@path}: #{e.message}"
      {}
    end

    def write
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, JSON.pretty_generate(@values))
    end
end
