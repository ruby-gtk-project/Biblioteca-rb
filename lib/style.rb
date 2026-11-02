# frozen_string_literal: true

require 'gtk4'

# Style is the application stylesheet.
#
# Ported from upstream's src/style.css, which the bundler turns into a
# GResource that src/main.js imports for its side effect. There is no bundler
# here, so the rules live in a Ruby heredoc and are loaded onto the default
# display with a Gtk::CssProvider.
#
# The rules are upstream's, unchanged:
#
#   * #top-toolbars gets an opaque background, dark or light, so the header bar
#     / tab bar / progress bar stack does not show the page through it;
#   * .searchbar rounds and shadows the find-in-page bar FindOverlay floats
#     over the web view;
#   * button.pill.small is Builder's small-pill style, used for the symbol-kind
#     tags beside each search result.
module Style
  CSS = <<~CSS
    @media (prefers-color-scheme: dark) {
      #top-toolbars {
        background-color: #121212;
      }
    }

    @media (prefers-color-scheme: light) {
      #top-toolbars {
        background-color: #ffffff;
      }
    }

    /* Enforce border radius */
    .searchbar > * > * {
      border-radius: 12px;
    }

    .searchbar {
      box-shadow:
        0 2px 5px 0px rgba(0, 0, 0, 0.09),
        0 2px 14px 0px rgba(0, 0, 0, 0.05);
    }

    /*
     * From Builder's stylesheet:
     * https://gitlab.gnome.org/GNOME/gnome-builder/-/blob/45d4ec9b6f1aa2236c9bb7dfb846b35f9b959618/src/libide/gui/style.css#L33
     * Used to style the language tags for the demo entries in the Library
     */
    button.pill.small {
      font-size: 0.83333em;
      border-radius: 99px;
      margin: 0;
      padding: 1px 12px;
    }
  CSS

  # Applied at APPLICATION priority, which is what GTK reserves for an app's
  # own stylesheet: above the theme, below a user override.
  def self.load
    provider.then do |css|
      Gtk::StyleContext.add_provider_for_display(
        Gdk::Display.default,
        css,
        Gtk::StyleProvider::PRIORITY_APPLICATION,
      )
    end
  end

  def self.provider
    @provider ||= Gtk::CssProvider.new.tap { |css| css.load(data: CSS) }
  end
end
