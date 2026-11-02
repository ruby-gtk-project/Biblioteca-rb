# frozen_string_literal: true

require 'gtk4'

require_relative 'package'

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
# The dialog itself is data/ui/shortcuts.ui, a line-for-line translation of
# src/Shortcuts.blp loaded with Gtk::Builder. It is a GtkShortcutsWindow, as
# upstream's is, so it keeps `modal: true`, `hide-on-close: true`, the
# section → group → shortcut hierarchy, the two
# `shortcut-type: gesture_two_finger_swipe_*` rows that draw GTK's swipe
# illustration, the two accelerators that list an alternative
# ("<Control>Page_Down <Control>Tab"), and the "<Alt>1...0" range.
#
# The accelerators the dialog lists and #accels does not bind are bound by
# Adwaita::TabView from its `shortcuts` property, which Window sets
# (lib/window.rb:400); binding them again at the application would shadow it.
class ShortcutsWindow
  UI_FILE = 'shortcuts.ui'
  UI_OBJECT = 'window_shortcuts'

  def initialize(app, window, default_uri:)
    @app = app
    @window = window
    @default_uri = default_uri
  end

  # Upstream's `accels` array (src/Shortcuts.js:10-30), plus app.quit from
  # src/actions.js and app.shortcuts, which Shortcuts() binds separately.
  def accels
    {
      "win.new-tab('#{@default_uri}')" => ['<Control>T'],
      'win.close-tab'                  => ['<Control>W'],
      'win.navigation-forward'         => ['<Alt>Right'],
      'win.navigation-back'            => ['<Alt>Left'],
      'win.zoom-in'                    => ['<Control>plus', '<Control>equal'],
      'win.zoom-out'                   => ['<Control>minus', '<Control>underscore'],
      'win.reset-zoom'                 => ['<Control>0'],
      'win.global-search'              => ['<Control>K'],
      'win.focus-urlbar'               => ['<Control>L'],
      'win.toggle-sidebar'             => ['F9'],
      'win.toggle-overview'            => ['<Shift><Control>O'],
      'win.find'                       => ['<Control>F'],
      'win.find-prev'                  => ['<Shift><Control>G'],
      'win.find-next'                  => ['<Control>G'],
      'win.close-find'                 => ['Escape'],
      'app.shortcuts'                  => ['<Control>question'],
      'app.quit'                       => ['<Control>Q'],
    }
  end

  # Registers app.shortcuts and binds every accelerator. Upstream calls the
  # equivalent at the end of the window's constructor.
  def install
    Gio::SimpleAction.new('shortcuts', nil).tap do |action|
      action.signal_connect('activate') { present }
      @app.add_action(action)
      accels.each { |name, keys| @app.set_accels_for_action(name, keys) }
    end
  end

  # Built on first use and kept, which is what upstream's `hide-on-close: true`
  # and its memoized `window_shortcuts` local amount to together.
  def present
    dialog.tap do |d|
      d.transient_for = @window
      d.present
    end
  end

  def dialog = @dialog ||= builder[UI_OBJECT]

  # The translation domain has to be set before the markup is parsed, so the
  # builder is constructed empty and fed the file afterwards.
  def builder
    @builder ||= Gtk::Builder.new.tap do |b|
      b.translation_domain = Package::DOMAIN
      b.add_from_file(Package.ui_path(UI_FILE))
    end
  end
end
