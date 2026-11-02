# frozen_string_literal: true

# Drives the whole application in a real GTK process.
#
# This is not a unit test: it boots Biblioteca::Application exactly as
# exe/biblioteca does, then walks the window's own action surface — the same
# `win.*` and `app.*` actions upstream's accelerators and menu items target —
# with the main loop running between steps so every widget gets realised,
# mapped and drawn. Anything the bindings reject raises here rather than in
# front of a user.
#
# Usage, from the dev shell:
#
#   xvfb-run -a ruby test/drive_app.rb
#
# Exits 0 when every step passed, 1 otherwise, and prints one line per step.
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'biblioteca'

# Runs an ordered list of named steps against a live application, one per main
# loop iteration, recording what each one raised.
class Driver
  def initialize
    @failures = []
    @steps = []
    @ran = 0
    @skipped = 0
  end

  def step(name, &body)
    @steps << [name, body]
    self
  end

  # A step that only means anything on a machine with gi-docgen API
  # documentation installed. The sidebar tree is read from that documentation,
  # so with none installed an empty tree is correct rather than broken, and
  # saying so is more use than a failure that is really a missing package.
  def documented_step(name, &body)
    if documented?
      step(name, &body)
    else
      step(name) { throw(:undocumented) }
    end
  end

  # The documentation root DocIndex settles on, with at least one gi-docgen
  # index.json under it.
  def documented?
    DocIndex.default_root.then do |root|
      root && !Dir.glob(File.join(root, '*', 'index.json')).empty?
    end
  end

  def run
    application.tap do |app|
      app.build.tap do |gtk_app|
        gtk_app.signal_connect('activate') { schedule(gtk_app) }
        gtk_app.run([])
      end
    end

    report
  end

  def application = @application ||= Biblioteca::Application.new

  def window = application.window

  def gtk_window = window.window

  private

    # One step per timeout so the main loop runs — and so a frame is drawn —
    # between them. The steps are consumed from the front; the last one quits.
    def schedule(gtk_app)
      GLib::Timeout.add(250) do
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
      catch(:undocumented) do
        @ran += 1
        body.call
        puts "ok    #{name}"
        :ran
      end.then do |outcome|
        unless outcome == :ran
          @ran -= 1
          @skipped += 1
          puts "skip  #{name} (no gi-docgen documentation installed)"
        end
      end
    rescue StandardError, SystemStackError => e
      @failures << [name, e]
      puts "FAIL  #{name}: #{e.class}: #{e.message}"
      puts "      #{e.backtrace.take(4).join("\n      ")}"
    end

    def report
      puts
      @failures.empty?.then do |clean|
        if clean
          puts "#{@ran} steps, #{@skipped} skipped, 0 failures"
          0
        else
          puts "#{@ran} steps, #{@skipped} skipped, " \
               "#{@failures.length} failure(s): #{@failures.map(&:first).join(', ')}"
          1
        end
      end
    end
end

# Asserts a condition the way the driver's steps want it: by raising.
module Expect
  def self.truthy(value, description)
    value.then do |v|
      unless v
        raise "expected #{description}, got #{v.inspect}"
      end
    end
    value
  end

  def self.equal(actual, expected, description)
    (actual == expected).then do |same|
      unless same
        raise "expected #{description} to be #{expected.inspect}, got #{actual.inspect}"
      end
    end
    actual
  end
end

Driver.new.tap do |driver|
  driver
    .step('window is realised') do
      Expect.truthy(driver.gtk_window.visible?, 'the window to be visible')
      Expect.truthy(driver.gtk_window.application, 'the window to belong to the application')
    end
    .step('first tab exists') do
      Expect.truthy(driver.window.webview, 'a web view on the first tab')
    end
    .documented_step('sidebar index loaded') do
      Expect.truthy(
        driver.window.sidebar.browse_view.root_model.n_items.positive?,
        'the browse tree to have root rows',
      )
    end
    .documented_step('search finds something') do
      driver.window.sidebar.search_view.tap do |view|
        view.search_term = 'button'
        Expect.truthy(view.n_items.positive?, 'search results for "button"')
      end
    end
    .step('search with a kind: prefix') do
      driver.window.sidebar.search_view.tap do |view|
        view.search_term = 'class: window'
        view.n_items
      end
    end
    .step('search is cleared') do
      driver.window.sidebar.search_view.tap do |view|
        view.search_term = ''
        Expect.equal(view.n_items, 0, 'an empty search to have no results')
      end
    end
    .step('win.global-search') { driver.gtk_window.activate_action('global-search', nil) }
    .step('win.focus-urlbar') { driver.gtk_window.activate_action('focus-urlbar', nil) }
    .step('win.new-tab') do
      driver.gtk_window.activate_action('new-tab', GLib::Variant.new(driver.window.default_uri, 's'))
    end
    .step('win.zoom-in') { driver.gtk_window.activate_action('zoom-in', nil) }
    .step('win.zoom-out') { driver.gtk_window.activate_action('zoom-out', nil) }
    .step('win.reset-zoom') do
      driver.gtk_window.activate_action('reset-zoom', nil)
      Expect.equal(driver.window.sidebar.zoom_buttons.zoom_level.round(2), 1.0, 'the zoom label')
    end
    .step('win.find') { driver.gtk_window.activate_action('find', nil) }
    .step('win.find-next') { driver.gtk_window.activate_action('find-next', nil) }
    .step('win.find-prev') { driver.gtk_window.activate_action('find-prev', nil) }
    .step('win.close-find') { driver.gtk_window.activate_action('close-find', nil) }
    .step('win.navigation-back') { driver.gtk_window.activate_action('navigation-back', nil) }
    .step('win.navigation-forward') { driver.gtk_window.activate_action('navigation-forward', nil) }
    .step('win.update-buttons') { driver.gtk_window.activate_action('update-buttons', nil) }
    .step('win.toggle-sidebar') { driver.gtk_window.activate_action('toggle-sidebar', nil) }
    .step('win.toggle-sidebar back') { driver.gtk_window.activate_action('toggle-sidebar', nil) }
    .step('win.toggle-overview') { driver.gtk_window.activate_action('toggle-overview', nil) }
    .step('win.toggle-overview back') { driver.gtk_window.activate_action('toggle-overview', nil) }
    .step('the theme selector has three choices') do
      Expect.equal(driver.window.sidebar.theme_selector.buttons.length, 3, 'the swatch count')
    end
    .step('app.color-scheme to dark') do
      driver.application.app.activate_action('color-scheme', GLib::Variant.new(4, 'i'))
    end
    .step('the dark swatch is lit') do
      Expect.truthy(
        driver.window.sidebar.theme_selector.buttons.last.active?,
        'the dark swatch to be active',
      )
    end
    .step('app.color-scheme back to default') do
      driver.application.app.activate_action('color-scheme', GLib::Variant.new(0, 'i'))
    end
    .step('the follow-system swatch is lit') do
      Expect.truthy(
        driver.window.sidebar.theme_selector.follow_button.active?,
        'the follow-system swatch to be active',
      )
    end
    .step('the main menu opens') { driver.window.sidebar.menu_button.popup }
    .step('the main menu closes') { driver.window.sidebar.menu_button.popdown }
    .step('app.shortcuts') { driver.application.app.activate_action('shortcuts', nil) }
    .step('app.about') { driver.application.app.activate_action('about', nil) }
    .step('win.close-tab') { driver.gtk_window.activate_action('close-tab', nil) }
    .run
    .then { |status| exit status }
end
