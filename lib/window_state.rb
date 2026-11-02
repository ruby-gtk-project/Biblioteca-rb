# frozen_string_literal: true

require 'gtk4'

# WindowState restores the window geometry the previous run left behind, and
# records it again when the window closes.
#
# Ported from `persistWindowState` in troll/src/util.js, the helper upstream's
# src/window.js calls as its first constructor statement. troll is a git
# submodule that this port's checkout does not carry, so the behaviour here is
# reconstructed from the four keys upstream's schema reserves for it
# (window-width, window-height, window-maximized, window-fullscreened) and
# from the single call site.
#
# One addition: a width or height of 0 — the schema's default, and so what a
# first run reads — is treated as "no stored size" and falls back to the
# default-width/default-height src/window.blp sets on the template. Handing
# Gtk::Window a default size of 0x0 would otherwise collapse the window on
# first launch.
class WindowState
  DEFAULT_WIDTH = 1080
  DEFAULT_HEIGHT = 768

  def initialize(settings)
    @settings = settings
  end

  # Applies the stored geometry and arms the save. Returns the window so the
  # caller can keep chaining, which is how upstream's constructor reads.
  def persist(window)
    window.tap do |win|
      win.set_default_size(stored_width, stored_height)
      if @settings['window-maximized']
        win.maximize
      end
      if @settings['window-fullscreened']
        win.fullscreen
      end

      # false, not true: the handler records the geometry and then lets the
      # close go through.
      win.signal_connect('close-request') do
        remember(win)
        false
      end
    end
  end

  # Records the geometry. The size is only written while the window is neither
  # maximized nor fullscreen, so what comes back is the size the user chose
  # rather than the size of their monitor.
  def remember(window)
    @settings['window-maximized'] = window.maximized?
    @settings['window-fullscreened'] = window.fullscreen?

    (window.maximized? || window.fullscreen?).then do |filling_the_screen|
      unless filling_the_screen
        @settings['window-width'] = window.default_width
        @settings['window-height'] = window.default_height
      end
    end
  end

  private

    def stored_width = positive_or(@settings['window-width'], DEFAULT_WIDTH)
    def stored_height = positive_or(@settings['window-height'], DEFAULT_HEIGHT)

    def positive_or(value, fallback)
      if value.to_i.positive?
        value.to_i
      else
        fallback
      end
    end
end
