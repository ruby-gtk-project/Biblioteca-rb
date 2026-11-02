# frozen_string_literal: true

# Entry point for the Ruby port of Biblioteca.
#
# One upstream source file maps to one file under lib/. Everything else is
# reached from Biblioteca::Application, which is what exe/biblioteca builds and
# runs:
#
#   biblioteca/application.rb  src/application.js, actions.js, main.js
#     package.rb               src/bin.js (imports.package.init), main.js
#     about_dialog.rb          src/about.js
#     settings.rb              data/app.gschema.xml, src/util.js
#     style.rb                 src/style.css
#     window.rb                src/window.blp + window.js
#       window_state.rb        troll/src/util.js (persistWindowState)
#       shortcuts_window.rb    src/Shortcuts.js, with src/Shortcuts.blp as
#                              data/ui/shortcuts.ui
#       find_overlay.rb        src/FindOverlay.blp + FindOverlay.js
#       web_view.rb            src/WebView.blp + WebView.js
#       sidebar.rb             src/sidebar/Sidebar.blp + Sidebar.js
#         sidebar_menu.rb      menu menu_app in src/sidebar/Sidebar.blp
#         theme_selector.rb    troll/src/widgets/ThemeSelector.{js,blp,css}
#         zoom_buttons.rb      src/sidebar/ZoomButtons.blp + ZoomButtons.js
#         browse_view.rb       src/sidebar/BrowseView.blp + BrowseView.js
#         search_view.rb       src/sidebar/SearchView.blp + SearchView.js
#         documentation_page.rb  src/sidebar/DocumentationPage.js
#         doc_index.rb         build-aux/build-index.js
#         fzy.rb               src/sidebar/fzy.js
#
# The installed data — the .desktop entry, the AppStream metainfo, the D-Bus
# service file, the GSettings schema, the icons and data/ui/shortcuts.ui — is
# upstream's data/ tree plus src/icons/, and lives under data/ here too.
require_relative "biblioteca/application"
