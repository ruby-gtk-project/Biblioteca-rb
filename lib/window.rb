# frozen_string_literal: true

require 'adwaita'
require 'webkit-gtk'

require_relative 'find_overlay'
require_relative 'shortcuts_window'
require_relative 'sidebar'
require_relative 'web_view'
require_relative 'window_state'

# Window is the application window: a tab overview over a split view, with the
# sidebar on the left and a tab view of documentation pages on the right.
#
# Ported from upstream's src/window.blp and src/window.js. The widget tree is
# the blueprint's, and the `win.*` action group is window.js's, one action per
# method.
#
# Four things worth knowing:
#
#   * a tab's child is a FindOverlay, not the web view — the find bar has to
#     float over the page — so reaching a tab's web view means going through
#     the overlay. `@overlays` maps each Adwaita::TabPage to the FindOverlay
#     that owns it, which is what upstream gets for free by reading
#     `selected_page.child.child`.
#   * upstream ties the web view's title, uri and zoom level to the header bar,
#     the tab, the window and the zoom row with GObject property bindings, and
#     rebuilds them for every new tab. Here each new tab connects the
#     equivalent notify handlers in #connect_webview; the moments they fire on
#     are the same.
#   * the two breakpoints set their properties from `apply` / `unapply`
#     handlers rather than from Adwaita::Breakpoint#add_setter, because the
#     wide breakpoint already needs an `apply` handler (moving the navigation
#     buttons between the header bar and the bottom bar is not a property
#     change), and splitting the same breakpoint's effects across two
#     mechanisms would hide half of them.
#   * the header bar shows a window title for a local page and a URL bar for a
#     remote one, which is what WebView's is_online? decides.
class Window
  TITLE = 'Biblioteca'
  DEFAULT_URI = ShortcutsWindow::DEFAULT_URI

  # The breakpoint conditions from src/window.blp.
  NARROW_WINDOW = 'max-width: 850sp'
  NARROW_CONTENT = 'max-width: 450sp'

  # The sidebar views' width request, wide normally and narrow once the window
  # is small enough for the sidebar to overlay the content.
  SIDEBAR_WIDTH = 400
  NARROW_SIDEBAR_WIDTH = 300

  # Upstream's zoom limits and step.
  ZOOM_STEP = 0.25
  ZOOM_MAX = 2.0
  ZOOM_MIN = 0.5

  # The actions that take no parameter. Every one has a method of the same
  # name with the dashes turned into underscores.
  ACTIONS = %w[
    close-tab
    navigation-forward
    navigation-back
    zoom-in
    zoom-out
    reset-zoom
    global-search
    focus-urlbar
    toggle-sidebar
    toggle-overview
    update-buttons
    find
    find-prev
    find-next
    close-find
  ].freeze

  HEADER_TITLE = 'title'
  HEADER_URL_BAR = 'url_bar'

  attr_reader :sidebar

  def initialize(app, settings:, devel: false)
    @app = app
    @settings = settings
    @devel = devel
    @overlays = {}
    @sidebar = Sidebar.new
  end

  def build
    window.tap do |win|
      win.content = tab_overview

      tab_overview.tap do |overview|
        overview.enable_new_tab = true
        overview.view = tab_view
        overview.child = split_view

        split_view.tap do |sv|
          sv.sidebar = sidebar.build
          sv.content = content_page

          content_page.tap do
            breakpoint_bin.tap do |bin|
              bin.add_breakpoint(toolbar_breakpoint)
              bin.child = toolbar_view
            end

            toolbar_view.tap do |view|
              view.add_top_bar(top_toolbars)
              view.add_bottom_bar(bottom_toolbar)
              view.content = tab_view

              top_toolbars.tap do |box|
                box.append(content_header_bar)
                box.append(tab_bar)
                box.append(load_bar)
              end

              content_header_bar.tap do |hb|
                hb.title_widget = header_bar_stack
                hb.pack_start(sidebar_button)
                hb.pack_start(box_navigation)
                hb.pack_end(new_tab_button)

                header_bar_stack.tap do |stack|
                  stack.add_named(window_title, HEADER_TITLE)
                  stack.add_named(url_bar_clamp, HEADER_URL_BAR)
                  stack.visible_child_name = HEADER_TITLE
                end

                box_navigation.tap do |nav|
                  nav.append(back_button)
                  nav.append(forward_button)
                end
              end

              bottom_toolbar.pack_end(tab_button)
            end
          end
        end
      end

      win.add_breakpoint(window_breakpoint)
      WindowState.new(@settings).persist(win)
      install_actions
      shortcuts.install
      connect_signals
    end
  end

  # Upstream's `open()`: present, focus the search, and reset the sidebar only
  # when the window had not been mapped yet — so a re-activation from the shell
  # does not throw away where the user had got to.
  def open
    window.mapped?.then do |mapped|
      window.present
      global_search
      unless mapped
        sidebar.reset_sidebar
      end
    end
  end

  # --- Window actions ------------------------------------------------------

  # Appends a tab on a fresh web view and selects it.
  def new_tab(uri = DEFAULT_URI)
    WebView.new(uri: uri, on_online_changed: method(:on_webview_online))
           .then { |view| FindOverlay.new(view.build) }
           .then { |overlay| attach_tab(overlay) }
  end

  # Closing the last tab closes the window, unless the overview is open — in
  # which case an empty overview is a reasonable place to be.
  def close_tab
    if tab_view.n_pages == 1 && !tab_overview.open?
      window.close
    else
      tab_view.close_page(tab_view.selected_page)
    end
  end

  def navigation_forward = webview&.go_forward
  def navigation_back = webview&.go_back

  def zoom_in
    webview.then do |view|
      if view && view.zoom_level < ZOOM_MAX
        apply_zoom(view, view.zoom_level + ZOOM_STEP)
      end
    end
  end

  def zoom_out
    webview.then do |view|
      if view && view.zoom_level > ZOOM_MIN
        apply_zoom(view, view.zoom_level - ZOOM_STEP)
      end
    end
  end

  def reset_zoom
    webview.then do |view|
      if view
        apply_zoom(view, 1.0)
      end
    end
  end

  def global_search
    tab_overview.open = false
    split_view.show_sidebar = true
    sidebar.focus_search
  end

  # Only reachable while the page is remote: there is no URL bar on a local
  # documentation page, because the header shows its title instead.
  def focus_urlbar
    if webview&.is_online?
      url_bar.grab_focus
    end
  end

  # Only toggles while the sidebar is an overlay. When it is a permanent pane
  # there is nothing to show or hide.
  def toggle_sidebar
    if split_view.collapsed? && !tab_overview.open?
      split_view.show_sidebar = !split_view.show_sidebar?
    end
  end

  def toggle_overview
    tab_overview.open = !tab_overview.open?
  end

  def update_buttons
    webview.then do |view|
      if view
        back_button.sensitive = view.can_go_back?
        forward_button.sensitive = view.can_go_forward?
      else
        back_button.sensitive = false
        forward_button.sensitive = false
      end
    end
  end

  def find = find_overlay&.show_find
  def find_prev = find_overlay&.find_prev
  def find_next = find_overlay&.find_next
  def close_find = find_overlay&.close_search

  # --- Memoized widget methods ---------------------------------------------

  # Adwaita::ApplicationWindow, not Gtk::ApplicationWindow: the Gtk one draws
  # its own titlebar, which would sit above the Adwaita header bar and give the
  # window a second close button. (Adwaita::Application is still broken in the
  # bindings; the application object stays a Gtk::Application.)
  def window
    @window ||= Adwaita::ApplicationWindow.new(@app).tap do |win|
      win.title = TITLE
      win.width_request = 360
      win.height_request = 360
      win.add_css_class('main-window')
      if @devel
        win.add_css_class('devel')
      end
    end
  end

  def tab_overview = @tab_overview ||= Adwaita::TabOverview.new
  def split_view = @split_view ||= Adwaita::OverlaySplitView.new

  # Adwaita::NavigationPage takes its child and title positionally, so the
  # breakpoint bin has to exist first.
  def content_page = @content_page ||= Adwaita::NavigationPage.new(breakpoint_bin, 'Documentation')

  def breakpoint_bin
    @breakpoint_bin ||= Adwaita::BreakpointBin.new.tap do |bin|
      bin.width_request = 360
      bin.height_request = 360
    end
  end

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

  # The name is what Style::CSS hangs the opaque background off, so the header
  # bar, the tab bar and the progress bar read as one surface.
  def top_toolbars
    @top_toolbars ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.name = 'top-toolbars'
    end
  end

  def content_header_bar = @content_header_bar ||= Adwaita::HeaderBar.new
  def header_bar_stack = @header_bar_stack ||= Gtk::Stack.new
  def window_title = @window_title ||= Adwaita::WindowTitle.new(TITLE, '')

  def url_bar_clamp = @url_bar_clamp ||= Adwaita::Clamp.new.tap { |clamp| clamp.child = url_bar }

  def url_bar
    @url_bar ||= Gtk::Entry.new.tap do |entry|
      entry.hexpand = true
      entry.input_purpose = :url
    end
  end

  # Hidden until the window is narrow enough for the sidebar to overlay the
  # content, which is the only time there is anything to toggle.
  def sidebar_button
    @sidebar_button ||= Gtk::ToggleButton.new.tap do |button|
      button.icon_name = 'sidebar-show-symbolic'
      button.tooltip_text = 'Open Sidebar'
      button.visible = false
      button.add_css_class('flat')
    end
  end

  def box_navigation
    @box_navigation ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.halign = :start
    end
  end

  def back_button
    @back_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'go-previous-symbolic'
      button.tooltip_text = 'Back'
      button.action_name = 'win.navigation-back'
      button.add_css_class('flat')
    end
  end

  def forward_button
    @forward_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'go-next-symbolic'
      button.tooltip_text = 'Forward'
      button.action_name = 'win.navigation-forward'
      button.add_css_class('flat')
    end
  end

  def new_tab_button
    @new_tab_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'tab-new-symbolic'
      button.tooltip_text = 'New Tab'
      button.action_name = 'win.new-tab'
      button.action_target = GLib::Variant.new(DEFAULT_URI)
      button.add_css_class('flat')
    end
  end

  def tab_bar = @tab_bar ||= Adwaita::TabBar.new.tap { |bar| bar.view = tab_view }

  def load_bar
    @load_bar ||= Gtk::ProgressBar.new.tap do |bar|
      bar.add_css_class('osd')
    end
  end

  def bottom_toolbar
    @bottom_toolbar ||= Gtk::ActionBar.new.tap do |bar|
      bar.visible = false
    end
  end

  # The tab counter that replaces the tab bar once the content is too narrow
  # for one.
  def tab_button
    @tab_button ||= Adwaita::TabButton.new.tap do |button|
      button.view = tab_view
      button.halign = :end
      button.visible = false
    end
  end

  # all_shortcuts is the blueprint's `shortcuts: all_shortcuts`: the tab view
  # binds Ctrl+Tab, Ctrl+Page_Up/Down, Ctrl+Home/End, their Shift variants for
  # reordering, and Alt+1..0 itself. Those are the accelerators the shortcuts
  # dialog lists under "Tabs" but ShortcutsWindow::ACCELS deliberately leaves
  # out.
  def tab_view
    @tab_view ||= Adwaita::TabView.new.tap do |view|
      view.vexpand = true
      view.shortcuts = Adwaita::TabViewShortcuts::ALL_SHORTCUTS
    end
  end

  def window_breakpoint
    @window_breakpoint ||= Adwaita::Breakpoint.new(
      Adwaita::BreakpointCondition.parse(NARROW_WINDOW),
    )
  end

  def toolbar_breakpoint
    @toolbar_breakpoint ||= Adwaita::Breakpoint.new(
      Adwaita::BreakpointCondition.parse(NARROW_CONTENT),
    )
  end

  def shortcuts = @shortcuts ||= ShortcutsWindow.new(@app, window)

  # The web view and find overlay of the tab that is currently selected.
  def webview = @webview
  def find_overlay = @find_overlay

  private

    def apply_zoom(view, level)
      view.zoom_level = level
      sidebar.zoom_buttons.zoom_level = level
    end

    def install_actions
      ACTIONS.each { |name| add_action(name) }
      add_new_tab_action
    end

    def add_action(name)
      Gio::SimpleAction.new(name, nil).tap do |action|
        action.signal_connect('activate') { send(name.tr('-', '_')) }
        window.add_action(action)
      end
    end

    # The one action with a parameter: the uri to open. ruby-gnome hands the
    # parameter over already unwrapped, so it arrives as a Ruby String.
    def add_new_tab_action
      Gio::SimpleAction.new('new-tab', GLib::VariantType.new('s')).tap do |action|
        action.signal_connect('activate') { |_, parameter| new_tab(parameter.to_s) }
        window.add_action(action)
      end
    end

    def connect_signals
      tab_button.signal_connect('clicked') { toggle_overview }

      # The handler has to hand the new page back: that is what the overview
      # animates into.
      tab_overview.signal_connect('create-tab') { new_tab }

      tab_view.signal_connect('notify::selected-page') { update_webview }
      tab_view.signal_connect('page-detached') { |_, page, _| @overlays.delete(page) }

      url_bar.signal_connect('activate') { on_activate_url_bar }

      connect_sidebar_toggle
      connect_breakpoints

      # Upstream creates the first tab from the window's constructor, before
      # any of this; here it comes last so every handler the tab needs is
      # already in place.
      new_tab
    end

    # The blueprint binds the toggle button's `active` and the split view's
    # `show-sidebar` to each other. Two handlers do the same job and settle,
    # because setting a boolean property to the value it already holds emits
    # nothing.
    def connect_sidebar_toggle
      sidebar_button.signal_connect('toggled') do
        split_view.show_sidebar = sidebar_button.active?
      end
      split_view.signal_connect('notify::show-sidebar') do
        sidebar_button.active = split_view.show_sidebar?
      end
    end

    def connect_breakpoints
      window_breakpoint.signal_connect('apply') { apply_narrow_window(true) }
      window_breakpoint.signal_connect('unapply') { apply_narrow_window(false) }
      toolbar_breakpoint.signal_connect('apply') { apply_narrow_content(true) }
      toolbar_breakpoint.signal_connect('unapply') { apply_narrow_content(false) }
    end

    # The window is too narrow for a permanent sidebar: collapse it and offer
    # the button that shows it. The views inside it shrink too, which is what
    # upstream adds with add_setters from #setupBreakpoint.
    def apply_narrow_window(narrow)
      split_view.collapsed = narrow
      sidebar_button.visible = narrow

      width = SIDEBAR_WIDTH
      if narrow
        width = NARROW_SIDEBAR_WIDTH
      end
      sidebar.browse_view.scroller.width_request = width
      sidebar.search_view.scroller.width_request = width
    end

    # The content is too narrow for a tab bar: swap it for the tab counter in a
    # bottom bar, and move the navigation buttons down there with it.
    def apply_narrow_content(narrow)
      bottom_toolbar.visible = narrow
      new_tab_button.visible = !narrow
      tab_bar.visible = !narrow
      tab_button.visible = narrow

      if narrow
        move_navigation_down
      else
        move_navigation_up
      end
    end

    def move_navigation_down
      content_header_bar.remove(box_navigation)
      bottom_toolbar.pack_start(box_navigation)
    end

    def move_navigation_up
      bottom_toolbar.remove(box_navigation)
      content_header_bar.pack_start(box_navigation)
    end

    def attach_tab(overlay)
      tab_view.append(overlay.build).tap do |page|
        @overlays[page] = overlay
        tab_view.selected_page = page
        update_webview
        connect_webview(overlay.webview, page)
      end
    end

    # Everything upstream set up as a property binding per tab.
    def connect_webview(view, page)
      view.signal_connect('notify::title') { on_title_changed(view, page) }
      view.signal_connect('notify::uri') { on_uri_changed(view) }
      view.signal_connect('notify::estimated-load-progress') { on_load_progress(view) }
      view.signal_connect('load-changed') { |_, event| on_load_changed(page, event) }
    end

    # The title reaches three places: the tab, the content page's header, and
    # the window. An empty title leaves all three as they were, which is what
    # upstream's bind_property_full returns false for.
    def on_title_changed(view, page)
      view.title.to_s.then do |title|
        unless title.empty?
          page.title = title
          content_page.title = title
          window.title = "#{title} - #{TITLE}"
          window_title.title = title
        end
      end
    end

    def on_uri_changed(view)
      if view.is_online? && view.equal?(webview)
        url_bar.text = view.uri.to_s
      end
    end

    # The load bar only tracks remote pages — a local file loads too fast for
    # the bar to be anything but a flicker — and empties itself half a second
    # after it fills, so it does not sit there full.
    def on_load_progress(view)
      if view.equal?(webview)
        if view.is_online?
          load_bar.fraction = view.estimated_load_progress
          if load_bar.fraction == 1
            GLib::Timeout.add(500) do
              load_bar.fraction = 0
              false
            end
          end
        else
          load_bar.fraction = 0
        end
      end
    end

    # if/elsif rather than case: `case event when :started` would ask the
    # Symbol whether it matches the enum, and only GLib::Enum#== knows how to
    # resolve a Symbol, so the enum has to be on the left.
    def on_load_changed(page, event)
      if event == :started
        page.loading = true
      elsif event == :finished
        page.loading = false
      end
    end

    # The selected tab changed: re-point everything that tracks "the current
    # web view" at the new one.
    def update_webview
      tab_view.selected_page.then do |page|
        @overlays[page].then do |overlay|
          if overlay
            @find_overlay = overlay
            @webview = overlay.webview
            sidebar.zoom_buttons.zoom_level = @webview.zoom_level
            update_buttons
            on_title_changed(@webview, page)
            on_webview_online(@webview)
            sidebar.browse_view.webview = @webview
          end
        end
      end
    end

    # A remote page gets the URL bar in the header and no selection in the
    # tree, because nothing in the tree is what is being shown. A local one
    # gets its title back.
    def on_webview_online(view)
      if view.equal?(webview) || webview.nil?
        if view.is_online?
          sidebar.browse_view.unselect_selection
          url_bar.text = view.uri.to_s
          header_bar_stack.visible_child_name = HEADER_URL_BAR
        else
          header_bar_stack.visible_child_name = HEADER_TITLE
        end
      end
    end

    # A URL typed without a scheme is assumed to be http, as upstream does.
    def on_activate_url_bar
      url_bar.text.then do |typed|
        if WebView.scheme_of(typed).nil?
          webview&.load_uri("http://#{typed}")
        else
          webview&.load_uri(typed)
        end
      end
    end
end
