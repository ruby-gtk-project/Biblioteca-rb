# frozen_string_literal: true

# Drives the sidebar's two GestureClick handlers —
# lib/browse_view.rb#on_pressed and lib/search_view.rb#on_pressed — with a
# real X11 pointer event, not a GObject signal_emit.
#
# FINDINGS and COMPONENT_PARITY both flagged that
# `Gtk::GestureClick#signal_emit('pressed', ...)` fires the signal handler but
# leaves `gesture.current_button` at 0 — confirmed directly below, as step
# zero of each view's run — so the middle-click branch both handlers gate on
# (`gesture.current_button == MIDDLE_BUTTON`) was never actually exercised by
# any driver in this port. `signal_emit` cannot fix that: `current_button` is
# set by GTK's own event-delivery code as it dispatches a *device* event to
# the gesture, not by the 'pressed' signal's arguments, so no combination of
# signal_emit arguments can populate it.
#
# This script instead synthesizes a real pointer press through the X server
# xvfb-run starts, using xdotool (XTest under the hood): move the pointer to
# a point inside the mapped widget, by window-relative coordinates xdotool
# resolves itself, and press/release the middle button there. GTK's own
# event pipeline then builds the button-press event, delivers it to the
# gesture, and sets current_button before 'pressed' fires — exactly the path
# a real user's middle click takes.
#
# Usage, from the dev shell:
#
#   xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_middle_click.rb
#
# Exits 0 when every step passed, 1 otherwise.
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'biblioteca'

# Shells out to xdotool to drive the X server the Ruby process and xvfb-run
# share. `mousemove --window` takes coordinates relative to the named
# window, so no screen-geometry arithmetic is needed in Ruby.
module Xdotool
  def self.window_id(title)
    `xdotool search --name #{title}`.strip.split("\n").first.tap do |id|
      if id.nil? || id.empty?
        raise "no X11 window titled #{title.inspect} was found"
      end
    end
  end

  def self.middle_click(title, x, y)
    id = window_id(title)
    system('xdotool', 'mousemove', '--sync', '--window', id, x.to_s, y.to_s) ||
      raise('xdotool mousemove failed')
    system('xdotool', 'click', '2') || raise('xdotool click failed')
  end

  def self.left_click(title, x, y)
    id = window_id(title)
    system('xdotool', 'mousemove', '--sync', '--window', id, x.to_s, y.to_s) ||
      raise('xdotool mousemove failed')
    system('xdotool', 'click', '1') || raise('xdotool click failed')
  end
end

# Asserts a condition the way the steps below want it: by raising.
module Expect
  def self.equal(actual, expected, description)
    unless actual == expected
      raise "expected #{description} to be #{expected.inspect}, got #{actual.inspect}"
    end

    actual
  end

  def self.truthy(value, description)
    unless value
      raise "expected #{description}, got #{value.inspect}"
    end

    value
  end
end

# Runs an ordered list of named steps on a GLib timeout, the same shape
# test/drive_sidebar.rb uses, since the widget steps need a live main loop.
class Driver
  def initialize(app_id)
    @app_id = app_id
    @failures = []
    @steps = []
    @ran = 0
  end

  def step(name, &body)
    @steps << [name, body]
    self
  end

  def run(&build_child)
    app.tap do |a|
      a.signal_connect('activate') do
        a.add_window(window)
        window.child = build_child.call(window)
        window.present
        schedule(a)
      end
      a.run([])
    end
    report
  end

  def app = @app ||= Adwaita.init.then { Gtk::Application.new(@app_id, :default_flags) }

  def window
    @window ||= Gtk::ApplicationWindow.new(app).tap do |win|
      win.title = @app_id
      win.set_default_size(400, 300)
    end
  end

  private

    def schedule(gtk_app)
      GLib::Timeout.add(300) do
        @steps.shift.then do |pair|
          if pair
            attempt(*pair)
            true
          else
            gtk_app.quit
            false
          end
        end
      end
    end

    def attempt(name, body)
      @ran += 1
      body.call
      puts "ok    #{name}"
    rescue StandardError => e
      @failures << [name, e]
      puts "FAIL  #{name}: #{e.class}: #{e.message}"
      puts "      #{e.backtrace.take(4).join("\n      ")}"
    end

    def report
      @failures.empty?.then do |clean|
        puts
        if clean
          puts "#{@ran} steps, 0 failures"
        else
          puts "#{@ran} steps, #{@failures.length} failure(s): #{@failures.map(&:first).join(', ')}"
        end
        clean
      end
    end
end

# A win.new-tab action that records every uri it was activated with, the
# same action both BrowseView#on_pressed and SearchView#on_pressed middle
# click into via `activate_action('win.new-tab', ...)`.
def install_recording_new_tab_action(window, opened)
  Gio::SimpleAction.new('new-tab', GLib::VariantType.new('s')).tap do |action|
    action.signal_connect('activate') { |_, parameter| opened << parameter.to_s }
    window.add_action(action)
  end
end

def run_browse_scenario
  Driver.new('org.rubygtkproject.Biblioteca.DriveMiddleClickBrowse').then do |driver|
    opened = []
    paths = {}
    browse_view = BrowseView.new(paths)

    driver
      .step('signal_emit leaves current_button at 0 (the bug this script works around)') do
        probe = Gtk::GestureClick.new.tap { |g| g.button = 0 }
        seen = nil
        probe.signal_connect('pressed') { |g, *| seen = g.current_button }
        probe.signal_emit('pressed', 1, 0.0, 0.0)
        Expect.equal(seen, 0, "signal_emit's current_button")
      end
      .step('the tree has one namespace, collapsed') do
        leaf = DocumentationPage.new(name: 'init', tag: 'function', uri: 'file:///gtk4/func.init.html')
        functions = DocumentationPage.list_store.tap { |s| s.append(leaf) }
        section = DocumentationPage.new(
          name: 'Functions',
          uri: 'file:///gtk4/index.html#functions',
          children: functions,
        )
        sections = DocumentationPage.list_store.tap { |s| s.append(section) }
        namespace = DocumentationPage.new(name: 'Gtk-4.0', uri: 'file:///gtk4/index.html', children: sections)
        browse_view.root_model.append(namespace)
        Expect.equal(browse_view.tree_model.n_items, 1, 'the collapsed row count')
      end
      .step('expanding the namespace and its Functions section reaches the leaf') do
        browse_view.tree_model.get_row(0).expanded = true
        browse_view.tree_model.get_row(1).expanded = true
        Expect.equal(browse_view.tree_model.n_items, 3, 'the expanded row count')
        Expect.equal(
          browse_view.tree_model.get_row(2).item.uri.to_s,
          'file:///gtk4/func.init.html',
          "row 2's uri",
        )
      end
      .step('a real middle click on the leaf row opens it in a new tab') do
        Xdotool.middle_click(driver.window.title, 50, 2 * BrowseView::ITEM_HEIGHT + 10)
        20.times { GLib::MainContext.default.iteration(false) }
        Expect.equal(opened, ['file:///gtk4/func.init.html'], 'the uris win.new-tab was activated with')
      end
      .step('a real left click on the same row does not open a new tab') do
        Xdotool.left_click(driver.window.title, 50, 2 * BrowseView::ITEM_HEIGHT + 10)
        20.times { GLib::MainContext.default.iteration(false) }
        Expect.equal(opened, ['file:///gtk4/func.init.html'], 'win.new-tab stays at one activation')
      end

    driver.run do |window|
      install_recording_new_tab_action(window, opened)
      browse_view.build
    end
  end
end

def run_search_scenario
  Driver.new('org.rubygtkproject.Biblioteca.DriveMiddleClickSearch').then do |driver|
    opened = []
    search_view = SearchView.new

    driver
      .step('one page is indexed and matches the search term') do
        page = DocumentationPage.new(
          name: 'init',
          tag: 'function',
          search_name: 'init',
          uri: 'file:///gtk4/func.init.html',
        )
        search_view.initialize_model([page])
        search_view.search_term = 'init'
        Expect.equal(search_view.n_items, 1, 'the result count')
      end
      .step('a real middle click on the only result opens it in a new tab') do
        Xdotool.middle_click(driver.window.title, 50, 10)
        20.times { GLib::MainContext.default.iteration(false) }
        Expect.equal(opened, ['file:///gtk4/func.init.html'], 'the uris win.new-tab was activated with')
      end
      .step('a real left click on the same result does not open a second tab') do
        Xdotool.left_click(driver.window.title, 50, 10)
        20.times { GLib::MainContext.default.iteration(false) }
        Expect.equal(opened, ['file:///gtk4/func.init.html'], 'win.new-tab stays at one activation')
      end

    driver.run do |window|
      install_recording_new_tab_action(window, opened)
      search_view.build
    end
  end
end

browse_ok = run_browse_scenario
search_ok = run_search_scenario

exit((browse_ok && search_ok) ? 0 : 1)
