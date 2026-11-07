# frozen_string_literal: true

require 'adwaita'

require_relative 'browse_view'
require_relative 'doc_index'
require_relative 'documentation_page'
require_relative 'package'
require_relative 'search_view'
require_relative 'sidebar_menu'
require_relative 'theme_selector'
require_relative 'zoom_buttons'

# Sidebar is the whole left-hand pane: the main menu, the search entry, and a
# stack holding the browse tree, the search results and a "no results" page.
#
# Ported from upstream's src/sidebar/Sidebar.blp and Sidebar.js. It owns the
# documentation index and both views built on top of it:
#
#   * the tree of nested Gio::ListStores BrowseView's Gtk::TreeListModel walks;
#   * a flat Ruby array of every searchable page, which is what SearchView
#     ranks (see that file for why the search side is Ruby rather than a
#     filter/sort model chain);
#   * `paths`, a uri => tree-path map. The tree path is the list of per-level
#     indices that reaches a page, and it is the only way to turn "the web view
#     is showing this uri" back into "select this row", because the tree is
#     lazy and a row that has never been expanded has no index yet.
#
# It is also where the two custom widgets get slotted into the menu popover,
# under the ids SidebarMenu reserves for them.
#
# Upstream reads doc-index.json out of pkgdatadir, where its build step wrote
# it. There is no build step here, so the index is read from the user's cache
# directory and built by DocIndex on the first run that finds nothing there.
class Sidebar
  include Package::Translatable

  # src/sidebar/Sidebar.blp:5 — not translated upstream.
  TITLE = 'Biblioteca'

  BROWSE = 'browse'
  SEARCH = 'search'
  NO_RESULTS = 'no-results'

  attr_reader :browse_view, :search_view, :paths

  def initialize(doc_index: nil)
    @paths = {}
    @doc_index = doc_index
    @browse_view = BrowseView.new(@paths, on_webview_changed: method(:on_webview_changed))
    @search_view = SearchView.new(on_selected: method(:on_search_selection))
    @searchable_pages = []
  end

  def build
    page.tap do
      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.add_top_bar(search_toolbar)
        view.content = stack

        header_bar.pack_end(menu_button)
        search_toolbar.append(search_entry)

        stack.tap do |s|
          s.add_named(browse_view.build, BROWSE)
          s.add_named(search_view.build, SEARCH)
          s.add_named(status_page, NO_RESULTS)
          s.visible_child_name = BROWSE
        end

        menu_popover.tap do |popover|
          popover.add_child(theme_selector.build, SidebarMenu::THEME_SELECTOR_ID)
          popover.add_child(zoom_buttons.build, SidebarMenu::ZOOM_BUTTONS_ID)
        end

        search_entry.signal_connect('search-changed') { on_search }
      end

      load_index
    end
  end

  # Folds the tree shut, selects the starting namespace and clears the search.
  # Upstream calls this when the window is presented for the first time.
  def reset_sidebar
    browse_view.collapse_all_rows
    browse_view.selection_model.selected = selection_index
    search_entry.text = ''
    stack.visible_child_name = BROWSE
  end

  # The uri of the namespace the sidebar opens on — Gtk-4.0 — read out of the
  # index that has already been built, so the window can open its first tab on
  # a page that exists on this machine. nil when the GTK documentation is not
  # installed, which is the same thing DocIndex#start_index reports as -1 —
  # guarded here rather than indexed directly, because Ruby's negative
  # indexing would otherwise silently hand back the *last* entry in `docs`
  # (see FINDINGS.md #11 — this guard is the one place the -1 case actually
  # changes anything observable; GTK's own selection model overrides it
  # everywhere else).
  def start_uri
    if start_index.negative?
      nil
    else
      doc_index.fetch('docs', [])[start_index]&.fetch('uri', nil)
    end
  end

  def focus_search
    search_entry.grab_focus
    search_entry.select_region(0, -1)
  end

  # Memoized widget methods

  # Adwaita::NavigationPage takes its child and title positionally, so the
  # toolbar view has to exist before the page does.
  def page = @page ||= Adwaita::NavigationPage.new(toolbar_view, TITLE)

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
  def header_bar = @header_bar ||= Adwaita::HeaderBar.new

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.menu_model = menu.model
      button.icon_name = 'open-menu-symbolic'
      button.tooltip_text = _('Main Menu')
      # primary: F10 opens it, as it does in every GNOME app.
      button.primary = true
    end
  end

  # The popover only exists once the menu button has a model, which is why this
  # is read rather than constructed.
  def menu_popover = @menu_popover ||= menu_button.popover

  def menu = @menu ||= SidebarMenu.new
  def theme_selector = @theme_selector ||= ThemeSelector.new
  def zoom_buttons = @zoom_buttons ||= ZoomButtons.new

  def search_toolbar
    @search_toolbar ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.add_css_class('toolbar')
    end
  end

  def search_entry
    @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
      entry.search_delay = 200
      entry.hexpand = true
      entry.placeholder_text = _('Search Biblioteca')
    end
  end

  def stack
    @stack ||= Gtk::Stack.new.tap do |s|
      s.transition_type = :none
    end
  end

  def status_page
    @status_page ||= Adwaita::StatusPage.new.tap do |sp|
      sp.title = _('No Results Found')
      sp.description = _('Try a different search term')
      sp.icon_name = 'edit-find-symbolic'
      sp.add_css_class('compact')
    end
  end

  private

    def doc_index = @doc_index ||= read_or_build_index

    # Upstream's doc_index.start_index (src/sidebar/Sidebar.js:59): -1 when
    # the Gtk-4.0 namespace is not indexed, unclamped here (an earlier round
    # clamped it to 0, which `start_uri` below showed to be the one place
    # that actually mattered — see FINDINGS.md #11 for why the on-screen
    # selection does not).
    def start_index = doc_index['start_index'].to_i

    # The value `start_index` is translated to for `selection_model.selected=`.
    # `GtkSingleSelection:autoselect` defaults true and neither upstream's
    # BrowseView.js nor BrowseView here turns it off, so on a non-empty tree
    # GTK reselects row 0 the instant anything else is assigned regardless of
    # what that is — upstream's raw -1 included. The sentinel assigned here
    # is therefore correct in principle without changing what is shown
    # (FINDINGS.md #11).
    def selection_index
      if start_index.negative?
        BrowseView::INVALID_POSITION
      else
        start_index
      end
    end

    # Builds the whole tree, then hands the flat page list to the search view
    # and selects the starting namespace. Upstream does the same work across a
    # batch of promises; there is nothing asynchronous about reading an
    # already-parsed hash, so it runs straight through here.
    def load_index
      doc_index.fetch('docs', []).each_with_index do |item, index|
        build_page(browse_view.root_model, item, [index])
      end

      browse_view.selection_model.selected = selection_index
      search_view.initialize_model(@searchable_pages)
    end

    # One DocumentationPage per index entry, appended to `parent`, with its tree
    # path recorded and its children built underneath it. A node with children
    # gets a list store for them whether or not it has a searchable name; a
    # node with a search_name also goes into the flat list the search uses.
    #
    # Child indices start at 1, not 0: a path's first element indexes the root
    # model, and every element after it counts rows below an already-expanded
    # parent, where index 0 is the parent itself.
    def build_page(parent, item, path)
      page_for(item).tap do |doc_page|
        @paths[item['uri']] = path.dup
        parent.append(doc_page)

        if doc_page.searchable?
          @searchable_pages << doc_page
        end

        item.fetch('children', []).each_with_index do |child, index|
          build_page(doc_page.children, child, path + [index + 1])
        end
      end
    end

    def page_for(item)
      DocumentationPage.new(
        name:        item['name'],
        tag:         item['tag'],
        search_name: item['search_name'],
        uri:         item['uri'],
        children:    children_store_for(item),
      )
    end

    def children_store_for(item)
      if item['children']
        DocumentationPage.list_store
      end
    end

    # Upstream reads doc-index.json straight out of pkgdatadir, where its build
    # step has already written it; nothing generates it at run time, so there is
    # nothing for it to invalidate. This port builds the index on first run
    # instead and caches it under XDG_CACHE_HOME, which introduces a staleness
    # upstream does not have: a machine with no API documentation installed yet
    # would cache an empty index and go on showing an empty tree long after the
    # documentation arrived. An index with no namespaces in it is therefore
    # neither read back from the cache nor written to it.
    def read_or_build_index
      usable(DocIndex.read(index_path)).then do |cached|
        if cached
          cached
        else
          build_index
        end
      end
    end

    def usable(index)
      if index&.fetch('docs', [])&.any?
        index
      end
    end

    def build_index
      DocIndex.new.then do |index|
        index.to_h.tap do
          if index.docs.any?
            index.write(File.dirname(index_path))
          end
        end
      end
    end

    def index_path
      File.join(
        ENV.fetch('XDG_CACHE_HOME', File.expand_path('~/.cache')),
        'biblioteca-rb',
        DocIndex::FILENAME,
      )
    end

    # Typing switches to the results; emptying the entry switches back to the
    # tree without disturbing what was selected there, which is why the
    # selection is read and written back around the switch.
    def on_search
      if search_entry.text.empty?
        browse_view.selection_model.selected.then do |index|
          stack.visible_child_name = BROWSE
          browse_view.selection_model.selected = index
        end
      else
        stack.visible_child_name = SEARCH
        search_view.search_term = search_entry.text
        if search_view.n_items.zero?
          stack.visible_child_name = NO_RESULTS
        end
      end
    end

    # The window has swapped in another tab's web view; follow it in the tree.
    def on_webview_changed(webview)
      @paths[webview.uri].then do |path|
        if path
          browse_view.select_item(path)
        end
      end
    end

    def on_search_selection(uri)
      @paths[uri].then do |path|
        if path
          browse_view.select_item(path)
        end
      end
    end
end
