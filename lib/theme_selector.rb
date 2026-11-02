# frozen_string_literal: true

require 'adwaita'

# ThemeSelector is the three-way light / dark / follow-system switch at the top
# of the main menu's popover.
#
# Ported from troll/src/widgets/ThemeSelector.js, which upstream's
# src/sidebar/Sidebar.js adds to the menu popover under the custom id
# "themeswitcher". troll is a git submodule this port's checkout does not
# carry, so the widget is reconstructed from its call site and from the shape
# every GNOME app's theme switcher shares: a box carrying libadwaita's
# `.theme-selector` style class with three radio buttons inside it, each of
# which targets `app.color-scheme` with the Adwaita::ColorScheme value it
# stands for.
#
# The style class is what draws the three swatches; libadwaita has shipped it
# since 1.2 for exactly this widget, so the buttons carry no labels of their
# own and the tooltips do the describing.
class ThemeSelector
  # Adwaita::ColorScheme values. Upstream stores the chosen one in the
  # color-scheme GSettings key and feeds it straight to
  # Adwaita::StyleManager#color_scheme, so these are the numbers the schema
  # holds: DEFAULT (follow the system), FORCE_LIGHT, FORCE_DARK.
  FOLLOW_SYSTEM = 0
  FORCE_LIGHT = 1
  FORCE_DARK = 4

  # [style class, tooltip, action target]. The style class is also what
  # libadwaita keys each swatch's appearance off.
  CHOICES = [
    ['follow', 'Follow System Style', FOLLOW_SYSTEM],
    ['light', 'Light Style', FORCE_LIGHT],
    ['dark', 'Dark Style', FORCE_DARK],
  ].freeze

  ACTION = 'app.color-scheme'

  def build
    box.tap do |b|
      buttons.each { |button| b.append(button) }
    end
  end

  def box
    @box ||= Gtk::Box.new(:horizontal, 6).tap do |b|
      b.homogeneous = true
      b.add_css_class('theme-selector')
    end
  end

  # One radio button per choice, grouped so only one is ever lit. The group is
  # cosmetic — GTK syncs each button's active state from the action's state, so
  # changing the setting from anywhere lights the right swatch.
  def buttons
    @buttons ||= CHOICES.map { |style, tooltip, target| button(style, tooltip, target) }
                        .tap { |group| group.drop(1).each { |button| button.group = group.first } }
  end

  private

    def button(style, tooltip, target)
      Gtk::CheckButton.new.tap do |check|
        check.add_css_class(style)
        check.tooltip_text = tooltip
        check.action_name = ACTION
        # Spelled out as int32: the schema key is an "i", and a bare Integer
        # would be wrapped as an int64 that never matches the action's type.
        check.action_target = GLib::Variant.new(target, 'i')
      end
    end
end
