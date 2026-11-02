# frozen_string_literal: true

require 'gtk4'

# WindowState persists the window geometry across runs.
#
# Ported from `persistWindowState` in troll/src/util.js
# (<https://github.com/sonnyp/troll>), the helper upstream's src/window.js
# calls as its first constructor statement. Both halves of that function are
# reproduced here:
#
#   * window-maximized and window-fullscreened are two-way bindings onto the
#     window's `maximized` and `fullscreened` properties
#     (Gio.SettingsBindFlags.DEFAULT), so they are written the moment the
#     window is maximized or unmaximized rather than at close;
#   * window-width and window-height are written from a handler on
#     notify::default-width and notify::default-height, debounced by 300 ms —
#     troll's comment is "Resizing the window triggers a lot of notify signals
#     so we use a debounced function instead of settings.bind".
#
# Because nothing waits for a close, a crash or a SIGTERM during a session
# loses at most the last 300 ms of resizing, which is the behaviour upstream
# has.
#
# One addition, in the same place troll puts it: troll applies the stored size
# only `if (width && height)`, so a first run — where the schema's default is
# 0 — keeps whatever default-width/default-height the template set. This port
# has no template, so WIDTH and HEIGHT below carry src/window.blp:6-7's
# default-width: 1080 / default-height: 768 and are applied in that case.
class WindowState
  # src/window.blp:6-7.
  WIDTH = 1080
  HEIGHT = 768

  # troll/src/util.js's `debounce(onSizeChanged, 300)`.
  DEBOUNCE_MS = 300

  def initialize(settings)
    @settings = settings
  end

  # Applies the stored geometry and arms the saves. Returns the window so the
  # caller can keep chaining, which is how upstream's constructor reads.
  def persist(window)
    window.tap do |win|
      @settings.bind('window-maximized', win, 'maximized')
      @settings.bind('window-fullscreened', win, 'fullscreened')

      win.signal_connect('notify::default-width') { schedule_size(win) }
      win.signal_connect('notify::default-height') { schedule_size(win) }

      apply_size(win)
    end
  end

  # Writes the size now rather than waiting for the debounce to elapse.
  def remember(window)
    @settings['window-width'] = window.default_width
    @settings['window-height'] = window.default_height
  end

  private

    # troll applies the stored size only when both keys are set; the schema's
    # default of 0 means "nothing stored yet".
    def apply_size(window)
      [@settings['window-width'].to_i, @settings['window-height'].to_i].then do |width, height|
        if width.positive? && height.positive?
          window.set_default_size(width, height)
        else
          window.set_default_size(WIDTH, HEIGHT)
        end
      end
    end

    # The debounce: every notify cancels the pending timeout and arms a new
    # one, so a drag-resize writes once, 300 ms after the user stops.
    def schedule_size(window)
      cancel_pending
      @timeout = GLib::Timeout.add(DEBOUNCE_MS) do
        @timeout = nil
        remember(window)
        false
      end
    end

    def cancel_pending
      @timeout.then do |id|
        if id
          GLib::Source.remove(id)
          @timeout = nil
        end
      end
    end
end
