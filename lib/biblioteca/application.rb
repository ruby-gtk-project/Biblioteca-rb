# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "../about_dialog"
require_relative "../settings"
require_relative "../style"
require_relative "../window"

module Biblioteca
  # The port's application object.
  #
  # Ported from upstream's src/application.js, src/actions.js and src/main.js,
  # which between them register the application, load the stylesheet, add the
  # app-level actions (quit, about, and the stateful color-scheme action the
  # theme selector drives), keep Adwaita's style manager in step with the
  # color-scheme setting, and open a single window on activation.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    # Upstream registers as app.drey.Biblioteca. The port keeps its own id so
    # that running it does not collide on the session bus with an installed
    # copy of the original.
    APP_ID = "org.rubygtkproject.Biblioteca"

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
      app.tap do |a|
        # startup fires once per process; the stylesheet only wants loading
        # onto the display once.
        a.signal_connect("startup") { Style.load }

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
        Gtk::Application.new(APP_ID, :default_flags)
      end
    end

    def settings = @settings ||= Settings.new

    def window = @window ||= Window.new(app, settings: settings)

    def style_manager = @style_manager ||= Adwaita::StyleManager.default

    private

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
