# frozen_string_literal: true

require 'adwaita'

require_relative 'documentation_page'

# BrowseView is the sidebar's documentation tree: every installed library, its
# sections, and every symbol inside them, in one expandable Gtk::ListView.
#
# Ported from upstream's src/sidebar/BrowseView.blp and BrowseView.js. The
# model chain is upstream's exactly —
#
#   root ListStore -> Gtk::TreeListModel -> Gtk::SingleSelection
#
# with passthrough off, so the selection model's items are Gtk::TreeListRows
# and the DocumentationPage sits behind `row.item`.
#
# Two things the upstream file is careful about and this one keeps:
#
#   * selecting a row loads its page, but syncing the selection to follow a
#     page the web view navigated to on its own must not load it again — hence
#     the uri comparison in the selection handler.
#   * Gtk::ListView#scroll_to leaves the target row flush against the edge of
#     the viewport often enough that upstream overshoots by one row and then
#     corrects by hand once the adjustment has settled. #adjust_scrolling is
#     that correction, and ITEM_HEIGHT is the row height it assumes.
#
# Upstream exposes `webview` as a GObject property and notifies on it; here the
# setter calls the `on_webview_changed` callback, which is what Sidebar used
# the notify for.
class BrowseView
  ITEM_HEIGHT = 38

  # Gdk::BUTTON_MIDDLE. The gesture is created with button 0 so it sees every
  # button and can pick the middle one out itself.
  MIDDLE_BUTTON = 2

  # GTK reports "nothing selected" as GTK_INVALID_LIST_POSITION, which arrives
  # in Ruby as a very large unsigned integer rather than nil.
  INVALID_POSITION = 0xFFFFFFFF

  attr_reader :root_model

  # `paths` is the uri => tree path map Sidebar fills in as it builds the tree;
  # it is shared rather than copied, because Sidebar keeps appending to it.
  def initialize(paths, on_webview_changed: nil)
    @paths = paths
    @on_webview_changed = on_webview_changed
    @root_model = DocumentationPage.list_store
    @scrolled_to = false
  end

  def build
    scroller.tap do |c|
      c.child = list_view

      list_view.tap do |lv|
        lv.model = selection_model
        lv.factory = list_factory
        lv.add_controller(click_gesture)

        # Activating a row (Enter, or a double click) folds it open or shut
        # rather than loading it, which is what upstream does.
        lv.signal_connect('activate') do |_, position|
          tree_model.get_row(position).then { |row| row.expanded = !row.expanded? }
        end
      end

      selection_model.signal_connect('selection-changed') { on_selection_changed }
      click_gesture.signal_connect('pressed') { |gesture, _, _, y| on_pressed(gesture, y) }
      vadjustment.signal_connect('value-changed') { adjust_scrolling }
    end
  end

  def webview = @webview

  def webview=(value)
    unless @webview == value
      if @webview && @uri_handler
        @webview.signal_handler_disconnect(@uri_handler)
      end
      @webview = value
      @uri_handler = @webview.signal_connect('notify::uri') { sync_selection }
      @on_webview_changed&.call(@webview)
    end
  end

  # Expands whatever has to be expanded to reach `path`, scrolls the row into
  # view and selects it. `path` is a list of per-level indices, the value
  # Sidebar recorded for each uri while building the tree.
  def select_item(path)
    item_index(path).then do |index|
      if index < selection_model.n_items
        scroll_to_row(index)
        selection_model.selected = index
        @scrolled_to = true
      end
    end
  end

  def unselect_selection
    selection_model.selected.then do |index|
      unless index == INVALID_POSITION
        selection_model.unselect_item(index)
      end
    end
  end

  # Folds the whole tree shut, which is what the window does when it is
  # re-presented from the shell.
  #
  # n_items is re-read on every pass, not snapshotted: collapsing a row drops
  # its descendants out of the model there and then, so the count shrinks as
  # the walk proceeds and a snapshotted bound would run off the end. Walking
  # forward is still right — once row i is shut, row i+1 is its next sibling.
  def collapse_all_rows
    index = 0
    while index < tree_model.n_items
      tree_model.get_row(index).expanded = false
      index += 1
    end
  end

  def selection_model
    @selection_model ||= Gtk::SingleSelection.new(tree_model).tap do |model|
      model.can_unselect = true
    end
  end

  def tree_model
    # passthrough false: the model hands out Gtk::TreeListRows, so a row knows
    # its depth and whether it is expanded. autoexpand false: the tree opens
    # collapsed and only the path to the current page is unfolded.
    @tree_model ||= Gtk::TreeListModel.new(@root_model, false, false) do |item|
      item.children
    end
  end

  def scroller
    @scroller ||= Gtk::ScrolledWindow.new.tap do |c|
      c.vexpand = true
      c.width_request = 400
    end
  end

  def list_view
    @list_view ||= Gtk::ListView.new.tap do |lv|
      lv.enable_rubberband = false
      lv.add_css_class('navigation-sidebar')
    end
  end

  def list_factory
    @list_factory ||= Gtk::SignalListItemFactory.new.tap do |factory|
      factory.signal_connect('setup') do |_, item|
        item.focusable = true
        item.child = row_template
      end

      factory.signal_connect('bind') do |_, item|
        item.child.tap do |expander|
          expander.list_row = item.item
          expander.child.text = item.item.item.name.to_s
        end
      end
    end
  end

  # A fresh expander per row; the factory's setup signal calls this once for
  # each row widget GTK decides to keep around.
  def row_template
    Gtk::TreeExpander.new.tap do |expander|
      expander.child = Gtk::Inscription.new.tap do |inscription|
        inscription.hexpand = true
        inscription.valign = :center
        inscription.nat_chars = 10
        inscription.text_overflow = :ellipsize_end
      end
    end
  end

  def click_gesture = @click_gesture ||= Gtk::GestureClick.new.tap { |g| g.button = 0 }

  def vadjustment = @vadjustment ||= list_view.vadjustment

  private

    # Overshoot by one row where there is one, so the row we actually want does
    # not land half under the bottom edge. scroll_to asserts the position is in
    # range, hence the last-row case.
    def scroll_to_row(index)
      if index + 1 == selection_model.n_items
        list_view.scroll_to(index, :none, nil)
      else
        list_view.scroll_to(index + 1, :none, nil)
      end
    end

    def on_selection_changed
      selection_model.selected_item.then do |row|
        if row && webview && webview.uri != row.item.uri
          webview.load_uri(row.item.uri)
        end
      end
    end

    # Follows the web view: when it navigates somewhere the tree knows about
    # — a link inside the docs, or the back button — select that row.
    def sync_selection
      selection_model.selected_item.then do |row|
        if row.nil? || webview.uri != row.item.uri
          @paths[webview.uri].then do |path|
            if path
              select_item(path)
            end
          end
        end
      end
    end

    # Middle click opens the row under the pointer in a new tab. The row is
    # worked out from the pointer's y and the scroll offset rather than asked
    # of the list view, because a gesture on the list view does not carry the
    # row it landed on.
    def on_pressed(gesture, y)
      if gesture.current_button == MIDDLE_BUTTON
        ((vadjustment.value + y) / ITEM_HEIGHT).floor.then do |index|
          if index < tree_model.n_items
            tree_model.get_row(index).item.uri.then do |uri|
              list_view.activate_action('win.new-tab', GLib::Variant.new(uri))
            end
          end
        end
      end
    end

    # Runs on every scroll, but only does anything on the one that
    # #select_item provoked: if the selected row came to rest exactly on an
    # edge of the viewport it is nudged a row clear of it.
    def adjust_scrolling
      if @scrolled_to
        @scrolled_to = false
        selection_model.selected.then do |index|
          unless index == INVALID_POSITION
            nudge((index + 1) * ITEM_HEIGHT - vadjustment.value)
          end
        end
      end
    end

    def nudge(bottom_edge)
      if bottom_edge.zero?
        vadjustment.value -= ITEM_HEIGHT
      elsif bottom_edge - ITEM_HEIGHT == vadjustment.page_size
        vadjustment.value += ITEM_HEIGHT
      end
    end

    # Walks `path` level by level, counting rows as it goes and skipping over
    # the descendants of any row that is already expanded, so that a path into
    # the tree becomes a flat index into the list view. Each level but the last
    # is expanded on the way through.
    def item_index(path)
      relative_index = 0
      absolute_index = 0
      skip = 0

      path.each_with_index do |target, depth|
        while relative_index < target
          tree_model.get_row(absolute_index).then do |row|
            if row.expanded?
              skip += row.children.n_items
            end
            if skip.zero?
              relative_index += 1
            else
              skip -= 1
            end
          end
          absolute_index += 1
        end

        # Every level but the deepest has to be open for the next one to exist.
        if depth < path.length - 1
          tree_model.get_row(absolute_index).expanded = true
          absolute_index += 1
          relative_index = 1
        end
      end

      absolute_index
    end
end
