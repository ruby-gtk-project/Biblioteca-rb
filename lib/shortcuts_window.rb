# frozen_string_literal: true

require 'adwaita'

# ShortcutsWindow is the keyboard-shortcuts dialog, and the place every
# accelerator in the app is bound.
#
# Ported from upstream's src/Shortcuts.blp and src/Shortcuts.js. Upstream's
# Shortcuts() does three things in one function — register `app.shortcuts`,
# bind every accelerator, and lazily open a GtkShortcutsWindow — and this class
# keeps all three together for the same reason: the list the dialog shows and
# the accelerators actually bound have to stay in step, and they only do that
# if they are edited side by side.
#
# Three deliberate differences:
#
#   * Adwaita::ShortcutsDialog rather than Gtk::ShortcutsWindow. GTK deprecated
#     the latter in 4.18 in favour of exactly this widget. Adw's dialog has one
#     level of grouping where GTK's had two (a window of sections of groups),
#     so upstream's four groups — Tabs, Navigation, Zoom, General — become four
#     sections, which is how they were being read anyway.
#   * upstream's two gesture entries (two-finger swipe left and right) are
#     listed as items with the gesture in the subtitle. Adw's items describe
#     accelerators, not gestures, so there is nowhere else to put them, and
#     dropping them would hide a feature the web view really has.
#   * three of upstream's listed accelerators are not literal accelerator
#     strings: two carry a second alternative in the same string
#     ("<Control>Page_Down <Control>Tab"), one is a range ("<Alt>1...0"), and a
#     fourth is a typo for <Control> ("<Ctrl>Home"). Adw's item takes one
#     accelerator, so the alternatives and the range are listed by their first
#     key and the typo is spelled correctly; every one of them is still bound,
#     by Adwaita::TabView's own shortcuts.
class ShortcutsWindow
  # The page a new tab opens on when nothing says otherwise. Upstream spells
  # this out in the accelerator's action target.
  DEFAULT_URI = 'file:///app/share/doc/gtk4/index.html'

  SECTIONS = {
    'Tabs'       => [
      { title: 'Open tab', accelerator: '<Control>T' },
      { title: 'Close tab', accelerator: '<Control>W' },
      { title: 'Switch to the next tab', accelerator: '<Control>Page_Down' },
      { title: 'Switch to the previous tab', accelerator: '<Control>Page_Up' },
      { title: 'Switch to the first tab', accelerator: '<Control>Home' },
      { title: 'Switch to the last tab', accelerator: '<Control>End' },
      { title: 'View all open tabs', accelerator: '<Shift><Control>O' },
      { title: 'Move current tab backward', accelerator: '<Control><Shift>Page_Up' },
      { title: 'Move current tab forward', accelerator: '<Control><Shift>Page_Down' },
      { title: 'Move current tab at the start', accelerator: '<Control><Shift>Home' },
      { title: 'Move current tab at the end', accelerator: '<Control><Shift>End' },
      { title: 'Switch to tabs 1⋯10', accelerator: '<Alt>1' },
    ],
    'Navigation' => [
      { title: 'Go back to the previous page', accelerator: '<Alt>Left' },
      { title: 'Go forward to the next page', accelerator: '<Alt>Right' },
      { title: 'Focus global search', accelerator: '<Control>K' },
      { title: 'Find in page', accelerator: '<Control>F' },
      { title: 'Find next match', accelerator: '<Control>G' },
      { title: 'Find previous match', accelerator: '<Shift><Control>G' },
      { title: 'Focus URL bar', accelerator: '<Control>L' },
      { title: 'Go back to the previous page', subtitle: 'Two-finger swipe right' },
      { title: 'Go forward to the next page', subtitle: 'Two-finger swipe left' },
    ],
    'Zoom'       => [
      { title: 'Zoom in', accelerator: '<Control>plus' },
      { title: 'Zoom out', accelerator: '<Control>minus' },
      { title: 'Reset zoom', accelerator: '<Control>0' },
    ],
    'General'    => [
      { title: 'Show sidebar', accelerator: 'F9' },
      { title: 'Shortcuts', accelerator: '<Control>question' },
    ],
  }.freeze

  # Upstream's `accels` array, plus app.quit from src/actions.js and
  # app.shortcuts, which Shortcuts() binds separately.
  #
  # The tab-switching and tab-reordering accelerators the dialog lists are not
  # here: Adwaita::TabView binds those itself from its `shortcuts` property,
  # which Window sets, so binding them again at the application would shadow
  # it.
  ACCELS = {
    "win.new-tab('#{DEFAULT_URI}')" => ['<Control>T'],
    'win.close-tab'                 => ['<Control>W'],
    'win.navigation-forward'        => ['<Alt>Right'],
    'win.navigation-back'           => ['<Alt>Left'],
    'win.zoom-in'                   => ['<Control>plus', '<Control>equal'],
    'win.zoom-out'                  => ['<Control>minus', '<Control>underscore'],
    'win.reset-zoom'                => ['<Control>0'],
    'win.global-search'             => ['<Control>K'],
    'win.focus-urlbar'              => ['<Control>L'],
    'win.toggle-sidebar'            => ['F9'],
    'win.toggle-overview'           => ['<Shift><Control>O'],
    'win.find'                      => ['<Control>F'],
    'win.find-prev'                 => ['<Shift><Control>G'],
    'win.find-next'                 => ['<Control>G'],
    'win.close-find'                => ['Escape'],
    'app.shortcuts'                 => ['<Control>question'],
    'app.quit'                      => ['<Control>Q'],
  }.freeze

  def initialize(app, window)
    @app = app
    @window = window
  end

  # Registers app.shortcuts and binds every accelerator. Upstream calls the
  # equivalent at the end of the window's constructor.
  def install
    Gio::SimpleAction.new('shortcuts', nil).tap do |action|
      action.signal_connect('activate') { present }
      @app.add_action(action)
      ACCELS.each { |name, accels| @app.set_accels_for_action(name, accels) }
    end
  end

  # Built on first use and kept, which is what upstream's `hide-on-close: true`
  # and its memoized `window_shortcuts` local amount to together.
  def present
    dialog.tap { |d| d.present(@window) }
  end

  def dialog
    @dialog ||= Adwaita::ShortcutsDialog.new.tap do |d|
      d.title = 'Keyboard Shortcuts'
      SECTIONS.each { |title, items| d.add(section(title, items)) }
    end
  end

  private

    def section(title, items)
      Adwaita::ShortcutsSection.new.tap do |s|
        s.title = title
        items.each { |item| s.add(shortcut_item(item)) }
      end
    end

    # Positional, not keyword, arguments — even though the error a no-argument
    # new raises advertises the signatures as "title: utf8,
    # accelerator: utf8". Passing them as keywords fails; positionally works.
    def shortcut_item(item)
      Adwaita::ShortcutsItem.new(item[:title], item[:accelerator].to_s).tap do |shortcut|
        if item[:subtitle]
          shortcut.subtitle = item[:subtitle]
        end
      end
    end
end
