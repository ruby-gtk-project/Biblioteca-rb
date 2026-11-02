# frozen_string_literal: true

require 'webkit-gtk'

# WebView is the web view one tab shows a documentation page in.
#
# Ported from upstream's src/WebView.blp and WebView.js. A WebKit::WebView
# subclass that, on top of the settings the blueprint sets:
#
#   * hides the sidebar devhelp generates into every page, because this app
#     has its own;
#   * injects the overshoot gradients that make a scrolled page look like it
#     belongs inside a GTK window;
#   * tracks whether the page it is on is remote, which is what decides between
#     the window title and the URL bar in the header;
#   * opens middle-clicked links in a new tab instead of the current one;
#   * strips the context-menu items that make no sense here.
#
# The Ruby bindings namespace WebKitGTK as `WebKitGtk`, not `WebKit`.
#
# Upstream exposes `is-online` as a GObject property and the window connects to
# notify::is-online. Here the window passes an `on_online_changed` callback,
# which fires at the same two moments: a navigation, and a load_uri.
class WebView < WebKitGtk::WebView
  type_register

  ONLINE_SCHEMES = %w[http https].freeze

  # Gdk::BUTTON_MIDDLE, as WebKit reports it on a navigation action.
  MIDDLE_BUTTON = 2

  # The scheme part of a URI, per RFC 3986, matched here rather than read with
  # GLib::Uri.peek_scheme as upstream does (src/WebView.js). nil for a string
  # with no scheme at all, which is what peek_scheme returns too. See
  # FINDINGS.md, "GLib::Uri is not in the Ruby bindings".
  SCHEME_PATTERN = /\A([a-zA-Z][a-zA-Z0-9+.\-]*):/

  def self.scheme_of(uri) = uri.to_s[SCHEME_PATTERN, 1]

  # Upstream's UNDESIRED_CONTEXT_MENU_ACTIONS. "Stop" and "Reload" are dropped
  # because they misbehave on local documentation
  # (https://github.com/workbenchdev/Biblioteca/issues/105); the rest are
  # dropped because this app has nowhere to put a new window or a download.
  UNDESIRED_CONTEXT_MENU_ACTIONS = %i[
    stop
    reload
    open_link_in_new_window
    download_link_to_disk
    open_image_in_new_window
    download_image_to_disk
    open_frame_in_new_window
    open_video_in_new_window
    open_audio_in_new_window
    download_video_to_disk
    download_audio_to_disk
  ].freeze

  # https://gitlab.com/news-flash/news_flash_gtk/-/blob/6c080e2b0cf6def97fc877f3cb817ba1e277f2f5/data/resources/article_view/overshoot_overlay.js
  OVERSHOOT_SCRIPT = <<~JS
    var body = document.body;
    var divTop = document.createElement('div');
    body.insertBefore(divTop, body.firstChild);
    var divBottom = document.createElement('div');
    body.insertAdjacentElement('beforeend', divBottom);

    window.addEventListener('scroll', on_scroll);

    function on_scroll() {
      if (window.scrollY > 0) {
          divTop.classList.add("overshoot-overlay-top");
      } else {
          divTop.classList.remove("overshoot-overlay-top");
      }

      var limit = Math.max(
          document.body.scrollHeight,
          document.body.offsetHeight,
          document.documentElement.clientHeight,
          document.documentElement.scrollHeight,
          document.documentElement.offsetHeight);
      var max_scroll = limit - window.innerHeight;

      if (window.scrollY >= max_scroll) {
          divBottom.classList.remove("overshoot-overlay-bottom");
      } else {
          divBottom.classList.add("overshoot-overlay-bottom");
      }
    }
  JS

  # https://gitlab.com/news-flash/news_flash_gtk/-/blob/6c080e2b0cf6def97fc877f3cb817ba1e277f2f5/data/resources/article_view/style.css#L22-33
  OVERSHOOT_STYLES = <<~CSS
    .overshoot-overlay-top {
      height: 100%;
      width: 100%;
      position: fixed;
      z-index: 1;
      left: 0;
      top: 0;
      box-shadow: inset 0 1px rgba(0, 0, 0, 0.07);
      background: linear-gradient(to bottom, rgba(0, 0, 0, 0.07), transparent 4px);
      overflow-x: hidden;
      pointer-events: none;
    }
    .overshoot-overlay-bottom {
      height: 100%;
      width: 100%;
      position: fixed;
      z-index: 2;
      left: 0;
      bottom: 0;
      background: linear-gradient(to top, rgba(0, 0, 0, 0.07), transparent 4px);
      overflow-x: hidden;
      pointer-events: none;
    }

    @media (prefers-color-scheme: dark) {
      .overshoot-overlay-top {
          box-shadow: inset 0 1px rgba(0, 0, 0, 0.36);
          background: linear-gradient(to bottom, rgba(0, 0, 0, 0.36), transparent 4px);
      }
      .overshoot-overlay-bottom {
        box-shadow: inset 0 -1px rgba(0, 0, 0, 0.36);
        background: linear-gradient(to top, rgba(0, 0, 0, 0.36), transparent 4px);
      }
    }
  CSS

  # The sidebar devhelp renders into each page, which Biblioteca replaces with
  # its own.
  HIDE_PAGE_SIDEBAR = '.devhelp-hidden { display: none; }'

  def initialize(uri:, on_online_changed: nil)
    super()
    @on_online_changed = on_online_changed
    @is_online = false
    @initial_uri = uri
  end

  def build
    tap do |view|
      view.vexpand = true

      view.settings.tap do |settings|
        settings.enable_back_forward_navigation_gestures = true
        settings.enable_developer_extras = false
        settings.enable_smooth_scrolling = true
      end

      view.user_content_manager.tap do |manager|
        manager.add_style_sheet(page_sidebar_stylesheet)
        manager.add_script(overshoot_script)
        manager.add_style_sheet(overshoot_stylesheet)
      end

      view.signal_connect('notify::uri') { update_is_online(view.uri) }
      view.signal_connect('decide-policy') { |_, decision, type| on_decide_policy(decision, type) }
      view.signal_connect('context-menu') { |_, menu, _| prune_context_menu(menu) }

      # The window's back/forward buttons are only sensitive when there is
      # somewhere to go, and the history list is what knows.
      view.back_forward_list.signal_connect('changed') do
        view.activate_action('win.update-buttons', nil)
      end

      view.load_uri(@initial_uri)
    end
  end

  def is_online? = @is_online

  # Overridden so that is-online is up to date *before* the load starts rather
  # than when the uri property catches up, which is what keeps the header from
  # flickering between the title and the URL bar.
  def load_uri(uri)
    update_is_online(uri)
    super
  end

  private

    def update_is_online(uri)
      online = ONLINE_SCHEMES.include?(self.class.scheme_of(uri).to_s)

      unless @is_online == online
        @is_online = online
        @on_online_changed&.call(self)
      end
    end

    # A middle-clicked link is taken out of the current tab's hands and opened
    # in a new one. Returning true means the decision has been dealt with.
    def on_decide_policy(decision, decision_type)
      if decision_type == :navigation_action
        decision.navigation_action.then do |action|
          if action.mouse_button == MIDDLE_BUTTON
            decision.ignore
            activate_action('win.new-tab', GLib::Variant.new(action.request.uri))
            true
          else
            false
          end
        end
      else
        false
      end
    end

    # Returning false lets WebKit show the (now shorter) menu.
    #
    # `any?` with the enum on the left, not Array#include?: GLib::Enum#==
    # resolves a Symbol to an enum value, but include? asks the Symbol first,
    # and Symbol#== against an enum is always false.
    def prune_context_menu(menu)
      menu.items.each do |item|
        if UNDESIRED_CONTEXT_MENU_ACTIONS.any? { |action| item.stock_action == action }
          menu.remove(item)
        end
      end
      false
    end

    def page_sidebar_stylesheet = user_stylesheet(HIDE_PAGE_SIDEBAR)
    def overshoot_stylesheet = user_stylesheet(OVERSHOOT_STYLES)

    # All frames, USER level: the rules have to beat the page's own stylesheet.
    def user_stylesheet(source)
      WebKitGtk::UserStyleSheet.new(
        source,
        :all_frames,
        :user,
        nil,
        nil,
      )
    end

    # Injected at document end, so document.body exists by the time it runs.
    def overshoot_script
      WebKitGtk::UserScript.new(
        OVERSHOOT_SCRIPT,
        :all_frames,
        :end,
        nil,
        nil,
      )
    end
end
