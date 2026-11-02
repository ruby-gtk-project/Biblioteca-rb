# frozen_string_literal: true

require 'adwaita'

# ZoomButtons is the zoom row in the main menu's popover: minus, the current
# level as a percentage, plus.
#
# Ported from upstream's src/sidebar/ZoomButtons.blp and ZoomButtons.js, which
# add it to the popover under the custom id "zoom_buttons". The buttons carry
# no handlers of their own — they drive the window's `win.zoom-out` and
# `win.zoom-in` actions, exactly as upstream's do, so the same accelerators and
# the same clamping apply either way.
#
# Upstream binds the webview's zoom-level property through to the label with
# bind_property_full. Here the window hands the level over with
# `zoom_level=` whenever it changes or the selected tab changes, which is the
# same two moments the binding fired on.
class ZoomButtons
  def build
    box.tap do |b|
      b.append(zoom_out_button)
      b.append(zoom_label)
      b.append(zoom_in_button)
    end
  end

  def zoom_level = @zoom_level ||= 1.0

  # A zoom level of 0 means "no webview to report on yet"; upstream's binding
  # returns false for that case and leaves the old label standing.
  def zoom_level=(value)
    value.to_f.then do |level|
      unless level.zero?
        @zoom_level = level
        zoom_label.label = "#{(level * 100).round}%"
      end
    end
  end

  def box
    @box ||= Gtk::Box.new(:horizontal, 0).tap do |b|
      b.homogeneous = true
    end
  end

  def zoom_out_button
    @zoom_out_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'zoom-out-symbolic'
      button.tooltip_text = 'Zoom out'
      button.action_name = 'win.zoom-out'
      button.halign = :center
      button.add_css_class('flat')
      button.add_css_class('circular')
    end
  end

  def zoom_in_button
    @zoom_in_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'zoom-in-symbolic'
      button.tooltip_text = 'Zoom in'
      button.action_name = 'win.zoom-in'
      button.halign = :center
      button.add_css_class('flat')
      button.add_css_class('circular')
    end
  end

  def zoom_label = @zoom_label ||= Gtk::Label.new('100%')
end
