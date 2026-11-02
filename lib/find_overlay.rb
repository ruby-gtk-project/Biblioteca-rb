# frozen_string_literal: true

require 'webkit-gtk'

require_relative 'web_view'

# FindOverlay is the find-in-page bar that floats over the top right corner of
# a web view, with the match counter, previous/next and a close button.
#
# Ported from upstream's src/FindOverlay.blp and FindOverlay.js. One of these
# wraps each web view, and it is the overlay — not the web view — that goes
# into the tab view, which is why Window reaches a tab's web view through
# `find_overlay.webview`.
#
# The counter is kept by hand rather than read back from WebKit, exactly as
# upstream does: WebKitFindController reports the total match count once, when
# a fresh search first finds something, and says nothing at all about which
# match is current. So a new search resets the counter to 1 of n, and
# next/previous walk it round, wrapping, because the search itself is run with
# WRAP_AROUND.
class FindOverlay
  MAX_MATCH_COUNT = 1000

  # css-name is construct-only on GtkWidget, so the one node that has to *be*
  # an `entry` — the box the find icon, the text and the counter sit inside, so
  # that GTK draws the three of them as a single entry — cannot be built with
  # Gtk::Box.new and configured afterwards. A Gtk::Builder snippet is the only
  # way to set it; everything else in this file is built in Ruby.
  ENTRY_BOX_UI = <<~XML
    <interface>
      <object class="GtkBox" id="entry_box">
        <property name="css-name">entry</property>
        <property name="valign">center</property>
        <property name="width-request">220</property>
        <child>
          <object class="GtkImage" id="find_icon">
            <property name="icon-name">edit-find-symbolic</property>
          </object>
        </child>
        <child>
          <object class="GtkText" id="search_text">
            <property name="hexpand">true</property>
            <property name="vexpand">true</property>
            <property name="width-chars">10</property>
            <property name="max-width-chars">10</property>
          </object>
        </child>
        <child>
          <object class="GtkLabel" id="label_info">
            <property name="xalign">1</property>
            <property name="opacity">0.5</property>
          </object>
        </child>
      </object>
    </interface>
  XML

  attr_reader :webview

  def initialize(webview)
    @webview = webview
    @current_match = 0
    @total_count = 0
    @new_search = false
  end

  def build
    overlay.tap do |o|
      o.child = @webview
      o.add_overlay(find_toolbar)

      find_toolbar.append(search_bar)

      search_bar.tap do |bar|
        bar.child = search_box
        bar.connect_entry(search_text)

        search_box.tap do |box|
          box.append(entry_box)
          box.append(navigation_box)
          box.append(close_button)

          navigation_box.tap do |nav|
            nav.append(previous_button)
            nav.append(next_button)
          end
        end
      end

      find_controller.tap do |controller|
        controller.signal_connect('found-text') { |_, count| on_found(count) }
        controller.signal_connect('failed-to-find-text') { on_not_found }
      end

      search_text.signal_connect('notify::text') { find }
    end
  end

  def show_find
    search_bar.search_mode = true
    search_text.grab_focus
  end

  # Runs on every keystroke, courtesy of notify::text. CASE_INSENSITIVE and
  # WRAP_AROUND are upstream's options, and the wrap is what lets the counter
  # roll over at either end.
  def find
    @new_search = true
    find_controller.search(search_text.text, find_options, MAX_MATCH_COUNT)
  end

  def find_next
    @new_search = false
    find_controller.search_next
    @current_match += 1
    if @current_match > @total_count
      @current_match = 1
    end
    update_label_info
  end

  def find_prev
    @new_search = false
    find_controller.search_previous
    @current_match -= 1
    if @current_match < 1
      @current_match = @total_count
    end
    update_label_info
  end

  def close_search
    @new_search = false
    search_bar.search_mode = false
    find_controller.search_finish
    @current_match = 0
    @total_count = 0
    update_label_info
  end

  # Memoized widget methods

  def overlay = @overlay ||= Gtk::Overlay.new

  # Pinned to the top right with upstream's margins, and not expanding, so the
  # bar sits over the page rather than stretching across it.
  def find_toolbar
    @find_toolbar ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.vexpand = false
      box.valign = :start
      box.hexpand = false
      box.halign = :end
      box.margin_top = 12
      box.margin_end = 24
    end
  end

  def search_bar
    @search_bar ||= Gtk::SearchBar.new.tap do |bar|
      bar.add_css_class('searchbar')
    end
  end

  def search_box = @search_box ||= Gtk::Box.new(:horizontal, 6)

  def navigation_box
    @navigation_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.add_css_class('linked')
    end
  end

  def previous_button
    @previous_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'go-up-symbolic'
      button.tooltip_text = 'Show Previous Result'
      button.action_name = 'win.find-prev'
    end
  end

  def next_button
    @next_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'go-down-symbolic'
      button.tooltip_text = 'Show Next Result'
      button.action_name = 'win.find-next'
    end
  end

  def close_button
    @close_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'window-close-symbolic'
      button.tooltip_text = 'Close Search'
      button.action_name = 'win.close-find'
      button.add_css_class('circular')
    end
  end

  def entry_builder = @entry_builder ||= Gtk::Builder.new(string: ENTRY_BOX_UI)
  def entry_box = @entry_box ||= entry_builder['entry_box']
  def search_text = @search_text ||= entry_builder['search_text']
  def label_info = @label_info ||= entry_builder['label_info']

  def find_controller = @find_controller ||= @webview.find_controller

  def find_options
    @find_options ||= WebKitGtk::FindOptions::CASE_INSENSITIVE |
                      WebKitGtk::FindOptions::WRAP_AROUND
  end

  private

    # Only a fresh search carries a usable count; the counts that arrive while
    # stepping through matches are the same total and would reset the position.
    def on_found(count)
      if @new_search
        @current_match = 1
        @total_count = count
        update_label_info
      end
    end

    def on_not_found
      @current_match = 0
      @total_count = 0
      update_label_info
    end

    def update_label_info
      if @total_count.zero?
        label_info.label = ''
      else
        label_info.label = "#{@current_match} of #{@total_count}"
      end
    end
end
