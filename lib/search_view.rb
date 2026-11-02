# frozen_string_literal: true

require 'adwaita'

require_relative 'documentation_page'
require_relative 'fzy'

# SearchView is the list of fuzzy search results the sidebar shows while there
# is something in the search entry.
#
# Ported from upstream's src/sidebar/SearchView.blp and SearchView.js.
#
# Upstream's model chain is
#
#   flattened ListStore -> Gtk::FilterListModel (a Gtk::CustomFilter rebuilt
#   per search term) -> Gtk::SortListModel (a Gtk::CustomSorter over a `score`
#   property the filter sets as a side effect) -> Gtk::SingleSelection
#
# and this port cannot use the middle two. GtkCustomSortFunc takes its two
# items as `gconstpointer`, which carries no type information, so the Ruby
# bindings hand the callback a pair of raw addresses rather than the
# DocumentationPages: a Gtk::CustomSorter cannot compare objects here at all.
#
# So the filtering and the sorting both happen in Ruby, in one pass per search
# term, and the result is spliced into a plain Gio::ListStore the selection
# model sits on. It is the same work — upstream's filter already visits every
# page and its sorter already orders every match. What it gives up is the
# incremental re-filtering GtkFilterListModel does when the underlying store
# changes, which matters not at all: the flattened set of pages is built once
# and never changes afterwards.
#
# The ranked pages are also kept in a Ruby array, and that array — not
# selection_model.selected_item — is what every read goes through, so a page is
# never read back out of a GTK model.
#
# A search term may be prefixed with a symbol kind — "method: get_child",
# "signal: notify" — in which case the prefix is stripped off and used as an
# extra filter on the page's tag. Matching is case-insensitive unless the term
# itself contains an upper-case letter, which is fzy's smart-case rule.
class SearchView
  # The symbol kinds a query may be narrowed by. These are the `tag` values
  # DocIndex writes, so the list has to stay in step with DocIndex#tag_for.
  QUERY_TYPES = %w[
    additional
    alias
    bitfield
    callback
    class
    constant
    constructor
    enum
    error
    function
    interface
    namespace
    macro
    method
    property
    signal
    struct
    union
    vfunc
  ].freeze

  QUERY_PATTERN = /\A(#{QUERY_TYPES.join("|")})\s*:\s*/i

  ITEM_HEIGHT = 38
  MIDDLE_BUTTON = 2

  # GTK reports "nothing selected" as GTK_INVALID_LIST_POSITION, which arrives
  # in Ruby as a very large unsigned integer rather than nil.
  INVALID_POSITION = 0xFFFFFFFF

  # A parsed search term: the fzy needle, the symbol kind the term narrowed to
  # (nil for an unprefixed term), and whether to match as typed.
  Query = Data.define(:needle, :tag, :case_sensitive) do
    def haystack_for(page)
      page.search_name.to_s.then { |name| case_sensitive ? name : name.downcase }
    end

    def keeps?(page) = tag.nil? || page.tag == tag
  end

  def initialize(on_selected: nil)
    @on_selected = on_selected
    @search_term = ''
    @pages = []
    @results = []
    @inhibit_emit = false
  end

  def build
    scroller.tap do |c|
      c.child = list_view

      list_view.tap do |lv|
        lv.model = selection_model
        lv.factory = list_factory
        lv.add_controller(click_gesture)
      end

      click_gesture.signal_connect('pressed') { |gesture, _, _, y| on_pressed(gesture, y) }
    end
  end

  # Sidebar calls this once the whole tree has been built, with every page that
  # carries a search_name. Nothing can be searched before it.
  def initialize_model(pages)
    @pages = pages
  end

  def search_term = @search_term

  def search_term=(value)
    unless @search_term == value
      @search_term = value.to_s
      unselect_selection
      refresh_results
      # scroll_to asserts the position is in range, so an empty result set has
      # to be left alone rather than scrolled to row 0.
      unless @results.empty?
        list_view.scroll_to(0, :none, nil)
      end
    end
  end

  def n_items = @results.length

  def unselect_selection
    selection_model.selected.then do |index|
      unless index == INVALID_POSITION
        selection_model.unselect_item(index)
      end
    end
  end

  # Memoized widget methods

  def results_store = @results_store ||= DocumentationPage.list_store

  def selection_model
    @selection_model ||= Gtk::SingleSelection.new(results_store).tap do |model|
      # autoselect off: an empty result set, or a fresh search, must leave
      # nothing selected rather than snapping to the first row and loading it.
      model.autoselect = false
      model.can_unselect = true
      model.signal_connect('selection-changed') { on_selection_changed }
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
        @results[item.position].then do |page|
          if page
            item.child.tap do |box|
              box.first_child.text = page.search_name.to_s
              box.last_child.label = page.tag.to_s
            end
          end
        end
      end
    end
  end

  # The fully qualified name, then the symbol kind as a small pill. The pill is
  # an insensitive button because that is what gives it Builder's pill styling
  # (see Style::CSS), not because it is meant to be pressed.
  def row_template
    Gtk::Box.new(:horizontal, 0).tap do |box|
      box.append(
        Gtk::Inscription.new.tap do |inscription|
          inscription.valign = :center
          inscription.hexpand = true
          inscription.nat_chars = 25
          inscription.text_overflow = :ellipsize_end
        end,
      )

      box.append(
        Gtk::Button.new.tap do |button|
          button.sensitive = false
          button.valign = :center
          button.add_css_class('pill')
          button.add_css_class('small')
          button.add_css_class('doc-tag')
        end,
      )
    end
  end

  def click_gesture = @click_gesture ||= Gtk::GestureClick.new.tap { |g| g.button = 0 }

  def vadjustment = @vadjustment ||= list_view.vadjustment

  private

    # One splice rather than a remove_all and a run of appends, so the list
    # view sees a single items-changed for the whole new result set.
    def refresh_results
      @results = rank(@search_term)
      results_store.splice(0, results_store.n_items, @results)
    end

    # Upstream's filter and its sorter in one pass: fzy's cheap match test over
    # every page, the full score only for the pages that survive it and the tag
    # filter, then highest score first.
    def rank(term)
      query_for(term).then do |query|
        @pages.filter_map { |page| scored(page, query) }
              .sort_by { |page| -page.score }
      end
    end

    def query_for(term)
      tag, text = split_query(term)
      needle = text.gsub(/\s+/, '')
      case_sensitive = needle.downcase != needle
      folded = needle.downcase
      if case_sensitive
        folded = needle
      end

      Query.new(needle: folded, tag: tag, case_sensitive: case_sensitive)
    end

    def scored(page, query)
      query.haystack_for(page).then do |haystack|
        if Fzy.match?(query.needle, haystack) && query.keeps?(page)
          page.score = Fzy.score(query.needle, haystack)
          page
        end
      end
    end

    # Splits an optional "kind:" prefix off the term.
    def split_query(term)
      QUERY_PATTERN.match(term).then do |matches|
        if matches
          [matches[1].downcase, term[matches[0].length..]]
        else
          [nil, term]
        end
      end
    end

    def selected_page = @results[position_of(selection_model.selected)]

    # -1 would index the array from the end, so an unselected model has to be
    # turned into something that cannot hit a row.
    def position_of(index)
      if index == INVALID_POSITION
        @results.length
      else
        index
      end
    end

    def on_selection_changed
      selected_page.then do |page|
        if page && @inhibit_emit
          @inhibit_emit = false
        elsif page
          @on_selected&.call(page.uri)
        end
      end
    end

    # Middle click opens the result under the pointer in a new tab. The
    # selection still moves to it, so the emit is inhibited for that one
    # change — otherwise the page would load into the current tab as well.
    def on_pressed(gesture, y)
      if gesture.current_button == MIDDLE_BUTTON
        ((vadjustment.value + y) / ITEM_HEIGHT).floor.then do |index|
          if index < @results.length
            @inhibit_emit = true
            selection_model.selected = index
            open_in_new_tab(@results[index])
          end
        end
      end
    end

    def open_in_new_tab(page)
      if page
        list_view.activate_action('win.new-tab', GLib::Variant.new(page.uri))
      end
    end
end
