# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "../about_dialog"
require_relative "../package"
require_relative "../settings"
require_relative "../style"
require_relative "../window"

module Biblioteca
  # The port's application object.
  #
  # Ported from upstream's src/application.js, src/actions.js, src/main.js and
  # the startup half of src/bin.js, which between them set the application
  # name, initialise gettext, register the application, load the stylesheet,
  # add the app-level actions (quit, about, and the stateful color-scheme
  # action the theme selector drives), keep Adwaita's style manager in step
  # with the color-scheme setting, and open a single window on activation.
  #
  # The application id, the icon name, the GSettings schema id, the gettext
  # domain and the .desktop basename all come from Package, which is where
  # upstream's `pkg.name` ends up.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    OPTION_CONTEXT_DESCRIPTION = "<https://biblioteca.sonny.re>"

    # Adwaita::ColorScheme, in value order. The color-scheme setting holds the
    # integer; the style manager wants the enum, and the Ruby bindings take it
    # as a symbol.
    COLOR_SCHEMES = %i[
      default
      force_light
      prefer_light
      prefer_dark
      force_dark
    ].freeze

    def build
      # src/bin.js:18 and src/main.js:4, both of which run before the
      # application object exists.
      Package.set_application_name
      Package.init_gettext

      app.tap do |a|
        # startup fires once per process; the stylesheet and the bundled icon
        # directory only want registering on the display once.
        a.signal_connect("startup") do
          Style.load
          register_icons
        end

        a.signal_connect("activate") do
          apply_color_scheme
          build_window
          window.open
        end

        a.set_option_context_description(OPTION_CONTEXT_DESCRIPTION)
        setup_actions
      end
    end

    def run = app.run([])

    # Adwaita::Application is broken in the Ruby bindings; the application
    # object comes from Gtk and only the window is Adwaita.
    def app
      @app ||= begin
        Adwaita.init
        Gtk::Application.new(Package.app_id, :default_flags)
      end
    end

    # src/bin.js:24 — `globalThis.__DEV__ = pkg.name.endsWith(".Devel")`. The
    # window draws the striped development header bar when this is true.
    def devel? = app.application_id.to_s.end_with?(Package::DEVEL_SUFFIX)

    def settings = @settings ||= Settings.new

    def window = @window ||= Window.new(app, settings: settings, devel: devel?)

    def style_manager = @style_manager ||= Adwaita::StyleManager.default

    def icon_theme = @icon_theme ||= Gtk::IconTheme.get_for_display(Gdk::Display.default)

    private

      # The seven symbolic icons upstream imports into its GResource
      # (src/icons/, imported from src/window.js and src/sidebar/Sidebar.js)
      # plus the application icons, all shipped under data/icons as a hicolor
      # tree. Adding the directory to the icon theme's search path is what
      # makes `icon-name: "tab-new-symbolic"` resolve.
      def register_icons
        icon_theme.add_search_path(Package.icon_dir)
      end

      def setup_actions
        add_quit_action
        add_about_action
        # Upstream's `application.add_action(settings.create_action(...))`.
        app.add_action(settings.color_scheme_action)
        settings.on_changed("color-scheme") { apply_color_scheme }
      end

      # Upstream's activate handler builds the window only when there is not
      # one already; a second activation — from the shell, or from a second
      # launch of the same application id — just re-presents it.
      def build_window
        unless @window_built
          @window_built = true
          window.build
        end
      end

      def add_quit_action
        Gio::SimpleAction.new("quit", nil).tap do |action|
          action.signal_connect("activate") { app.quit }
          app.add_action(action)
        end
      end

      def add_about_action
        Gio::SimpleAction.new("about", nil).tap do |action|
          action.signal_connect("activate") { AboutDialog.new(app).present }
          app.add_action(action)
        end
      end

      # The stored value is an Adwaita::ColorScheme enum value, which is what
      # the theme selector's three choices set it to.
      def apply_color_scheme
        style_manager.color_scheme = COLOR_SCHEMES.fetch(settings["color-scheme"].to_i, :default)
      end
  end
end
