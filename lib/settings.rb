# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'gtk4'

# Settings holds the five keys of upstream's data/app.gschema.xml:
# color-scheme, window-width, window-height, window-maximized and
# window-fullscreened, with upstream's defaults (0, 0, 0, false, false).
#
# Upstream reaches them through Gio::Settings, which needs a compiled schema
# installed into a directory on XDG_DATA_DIRS. Requiring an install step before
# the app will run from a checkout is worse than the alternative, so the same
# keys, defaults and semantics are backed by a small JSON file under
# XDG_CONFIG_HOME instead. (This is the same trade the pilot port made.)
#
# The one Gio::Settings feature that has to be replaced rather than imitated is
# `settings.create_action("color-scheme")`, which upstream hands to the theme
# selector; `#color_scheme_action` builds the equivalent stateful action.
class Settings
  DEFAULTS = {
    'color-scheme'        => 0,
    'window-width'        => 0,
    'window-height'       => 0,
    'window-maximized'    => false,
    'window-fullscreened' => false,
  }.freeze

  def initialize(path: nil)
    @path = path || default_path
    @values = DEFAULTS.merge(read)
    @watchers = {}
  end

  def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

  def []=(key, value)
    @values[key.to_s] = value
    write
    @watchers.fetch(key.to_s, []).each { |block| block.call(value) }
    value
  end

  def location = @path

  # Named accessors for every key, so callers do not repeat the strings:
  # `settings.color_scheme`, `settings.window_width = 1080`.
  DEFAULTS.each_key do |key|
    method_name = key.tr('-', '_')
    define_method(method_name) { self[key] }
    define_method(:"#{method_name}=") { |value| self[key] = value }
    if DEFAULTS[key] == false
      define_method(:"#{method_name}?") { self[key] == true }
    end
  end

  # Upstream's `settings.connect("changed::color-scheme", setColorScheme)`.
  def on_changed(key, &block)
    @watchers[key.to_s] ||= []
    @watchers[key.to_s] << block
  end

  # Upstream's `settings.create_action("color-scheme")`: a stateful action
  # whose state is the Adwaita::ColorScheme enum value the style manager takes,
  # and which the theme selector's three radio buttons target.
  #
  # The variant type has to be spelled out. GLib::Variant.new(0) with no type
  # builds an int64, and the schema key — along with every action-target the
  # theme selector sets — is an int32.
  def color_scheme_action
    @color_scheme_action ||= Gio::SimpleAction.new(
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

  private

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
