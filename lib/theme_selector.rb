# frozen_string_literal: true

require 'adwaita'

require_relative 'package'

# ThemeSelector is the three-way follow-system / light / dark switch at the top
# of the main menu's popover.
#
# Ported from troll/src/widgets/ThemeSelector.js, .blp and .css
# (<https://github.com/sonnyp/troll>), which upstream's
# src/sidebar/Sidebar.js:82 adds to the menu popover under the custom id
# "themeswitcher". The widget tree, the three style classes, the three action
# targets, the three labels, the CSS and both style-manager handlers are
# troll's.
#
# What the widget does, all of it from ThemeSelector.js:
#
#   * the follow-system button is visible only while
#     Adwaita::StyleManager#system_supports_color_schemes? is true, and follows
#     notify::system-supports-color-schemes;
#   * the root carries the `dark` style class while the style manager reports a
#     dark theme, and follows notify::dark. That is what lets the stylesheet
#     draw the checkmark against the right background;
#   * the stylesheet is loaded onto the display once per process.
#
# One thing ThemeSelector.blp has that this does not: each button's
# `accessibility { label: ... }`. Here the label reaches the button as its
# tooltip only, so a screen reader announces the tooltip rather than a
# dedicated accessible label. See FINDINGS.md.
#
# The CSS below is troll's ThemeSelector.css with one mechanical change: troll
# registers the widget under the CSS node name `themeselector` (GObject
# `CssName`), and every rule is written against that element. The Ruby
# bindings expose no way to set a widget class's CSS name, so the root carries
# the style class `.themeselector` and each rule selects `.themeselector`
# instead of `themeselector`. Same rules, same specificity order; see
# FINDINGS.md.
class ThemeSelector
  include Package::Translatable

  # Adwaita::ColorScheme values, which are what ThemeSelector.blp's
  # action-target "0" / "1" / "4" are and what the color-scheme key stores:
  # DEFAULT, FORCE_LIGHT, FORCE_DARK.
  FOLLOW_SYSTEM = 0
  FORCE_LIGHT = 1
  FORCE_DARK = 4

  ACTION = 'app.color-scheme'

  # [style class, label, action target], in ThemeSelector.blp's order.
  CHOICES = [
    ['follow', _('Follow system style'), FOLLOW_SYSTEM],
    ['light', _('Light style'), FORCE_LIGHT],
    ['dark', _('Dark style'), FORCE_DARK],
  ].freeze

  SPACING = 12

  DARK_CLASS = 'dark'
  ROOT_CLASS = 'themeselector'

  CSS = <<~CSS
    .themeselector {
      margin: 9px;
    }

    .themeselector checkbutton {
      padding: 0;
      min-height: 44px;
      min-width: 44px;
      padding: 1px;
      background-clip: content-box;
      border-radius: 9999px;
      box-shadow: inset 0 0 0 1px @borders;
    }

    .themeselector checkbutton.follow:checked,
    .themeselector checkbutton.light:checked,
    .themeselector checkbutton.dark:checked {
      box-shadow: inset 0 0 0 2px @theme_selected_bg_color;
    }

    .themeselector checkbutton.follow {
      background-image: linear-gradient(
        to bottom right,
        #fff 49.99%,
        #202020 50.01%
      );
    }

    .themeselector checkbutton.light {
      background-color: #fff;
    }

    .themeselector checkbutton.dark {
      background-color: #202020;
    }

    .themeselector checkbutton radio {
      -gtk-icon-source: none;
      border: none;
      background: none;
      box-shadow: none;
      min-width: 12px;
      min-height: 12px;
      transform: translate(27px, 14px);
      padding: 2px;
    }

    checkbutton.theme-selector radio:checked {
      -gtk-icon-source: -gtk-icontheme("object-select-symbolic");
      background-color: @theme_selected_bg_color;
      color: @theme_selected_fg_color;
    }
  CSS

  # Loaded once per process, as troll's module-level `provider` is.
  def self.load_css
    @provider ||= Gtk::CssProvider.new.tap do |css|
      css.load(data: CSS)
      Gtk::StyleContext.add_provider_for_display(
        Gdk::Display.default,
        css,
        Gtk::StyleProvider::PRIORITY_APPLICATION,
      )
    end
  end

  def build
    self.class.load_css

    bin.tap do |root|
      root.child = box

      box.tap do |b|
        buttons.each { |button| b.append(button) }
      end

      style_manager.tap do |manager|
        manager.signal_connect('notify::system-supports-color-schemes') { apply_system_support }
        manager.signal_connect('notify::dark') { apply_dark }
      end

      apply_system_support
      apply_dark
    end
  end

  def bin
    @bin ||= Adwaita::Bin.new.tap do |root|
      root.hexpand = true
      root.add_css_class(ROOT_CLASS)
    end
  end

  def box
    @box ||= Gtk::Box.new(:horizontal, SPACING).tap do |b|
      b.hexpand = true
    end
  end

  # One check button per choice, grouped so only one is ever lit. The group is
  # cosmetic — GTK syncs each button's active state from the action's state, so
  # changing the setting from anywhere lights the right swatch.
  def buttons
    @buttons ||= CHOICES.map { |style, label, target| button(style, label, target) }
                        .tap { |group| group.drop(1).each { |b| b.group = group.first } }
  end

  # ThemeSelector.js's `this._follow`.
  def follow_button = buttons.first

  def style_manager = @style_manager ||= Adwaita::StyleManager.default

  private

    def apply_system_support
      follow_button.visible = style_manager.system_supports_color_schemes?
    end

    def apply_dark
      if style_manager.dark?
        bin.add_css_class(DARK_CLASS)
      else
        bin.remove_css_class(DARK_CLASS)
      end
    end

    def button(style, label, target)
      Gtk::CheckButton.new.tap do |check|
        check.add_css_class('theme-selector')
        check.add_css_class(style)
        check.hexpand = true
        check.halign = :center
        check.focus_on_click = false
        check.tooltip_text = label
        check.action_name = ACTION
        # Spelled out as int32: the schema key is an "i", and a bare Integer
        # would be wrapped as an int64 that never matches the action's type.
        check.action_target = GLib::Variant.new(target, 'i')
      end
    end
end
