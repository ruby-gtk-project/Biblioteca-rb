# frozen_string_literal: true

# Entry point for the Ruby port of Biblioteca.
#
# One upstream source file maps to one file under lib/. Everything else is
# reached from Biblioteca::Application, which is what exe/biblioteca builds and
# runs:
#
#   biblioteca/application.rb  src/application.js, actions.js, main.js
#     about_dialog.rb          src/about.js
#     settings.rb              data/app.gschema.xml
#     style.rb                 src/style.css
#     window.rb                src/window.blp + window.js
#       window_state.rb        troll/src/util.js (persistWindowState)
#       shortcuts_window.rb    src/Shortcuts.blp + Shortcuts.js
#       find_overlay.rb        src/FindOverlay.blp + FindOverlay.js
#       web_view.rb            src/WebView.blp + WebView.js
#       sidebar.rb             src/sidebar/Sidebar.blp + Sidebar.js
#         sidebar_menu.rb      menu menu_app in src/sidebar/Sidebar.blp
#         theme_selector.rb    troll/src/widgets/ThemeSelector.js
#         zoom_buttons.rb      src/sidebar/ZoomButtons.blp + ZoomButtons.js
#         browse_view.rb       src/sidebar/BrowseView.blp + BrowseView.js
#         search_view.rb       src/sidebar/SearchView.blp + SearchView.js
#         documentation_page.rb  src/sidebar/DocumentationPage.js
#         doc_index.rb         build-aux/build-index.js
#         fzy.rb               src/sidebar/fzy.js
require_relative "biblioteca/application"
