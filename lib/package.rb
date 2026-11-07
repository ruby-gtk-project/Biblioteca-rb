# frozen_string_literal: true

require 'gettext'
require 'glib2'

# Package is what GJS's `pkg` is: the one place that knows the application id,
# the version, and where the installed data lives.
#
# Ported from upstream's src/bin.js, which calls `imports.package.init({ name,
# version, prefix, libdir, datadir })` and then `GLib.set_application_name`,
# and from src/main.js, which calls `pkg.initGettext()`.
#
# Everything downstream of the application id — the icon name, the GSettings
# schema id, the gettext domain, the .desktop basename and the D-Bus name —
# is derived from BASE_APP_ID here rather than spelled out again, which is what
# upstream gets from threading `pkg.name` through meson's `app_id`.
#
# What this file does not reproduce, and what replaces it:
#
#   * src/bin.js:27-32 refuses to start outside Flatpak
#     (`Xdp.Portal.running_under_flatpak()`). This port is a gem, installed by
#     RubyGems and run from a checkout or from the system Ruby, so there is no
#     sandbox to require and the guard would reject every supported way of
#     running it. That condition is not replicated — there is nothing to
#     check — but exe/biblioteca refuses to start on the condition this port
#     can check instead: no GTK/GNOME API documentation installed anywhere
#     DocIndex::DEFAULT_ROOTS looks (lib/doc_index.rb:34-40). Without that
#     guard the app opens on a permanently empty sidebar with no explanation,
#     which is the same failure upstream's guard exists to head off.
#   * src/application.js:11 sets `resource_base_path: "/app/drey/Biblioteca"`
#     so that the Devel build loads its GResource from the release build's
#     prefix. This port ships no GResource — the stylesheet is a heredoc
#     (lib/style.rb) and the one .ui file is read from disk (ui_path below) —
#     so there is no resource path to rebase.
#   * src/biblioteca is a shell wrapper that sets LANG=en_US.UTF-8 to force the
#     AboutWindow into English, because upstream ships no catalogue. This port
#     marks its strings and ships po/, so it does not force a locale;
#     exe/biblioteca is the launcher and sets no environment.
module Package
  NAME = 'Biblioteca'

  # Upstream registers app.drey.Biblioteca (and app.drey.Biblioteca.Devel for
  # a development build). The port keeps its own id so that running it does not
  # collide on the session bus with an installed copy of the original.
  #
  # BIBLIOTECA_DEVEL in the environment selects the Devel id, which is what
  # meson's `-Dprofile=development` does upstream (meson.build:9).
  BASE_APP_ID = 'org.rubygtkproject.Biblioteca'
  DEVEL_SUFFIX = '.Devel'

  # The gettext domain is the application id, as upstream's
  # `pkg.initGettext()` makes it (and as data/app.gschema.xml's
  # gettext-domain and data/app.metainfo.xml's <translation> name).
  #
  # The domain is the *release* id even for a Devel build, so that one
  # catalogue serves both — upstream's `pkg.initGettext()` uses pkg.name and so
  # orphans the Devel build's catalogue; see FINDINGS.md.
  DOMAIN = BASE_APP_ID

  def self.devel? = !ENV['BIBLIOTECA_DEVEL'].to_s.empty?

  def self.app_id
    if devel?
      "#{BASE_APP_ID}#{DEVEL_SUFFIX}"
    else
      BASE_APP_ID
    end
  end

  # The icon installed as data/icons/hicolor/scalable/apps/<app_id>.svg, which
  # is also what data/app.desktop's Icon= and the About dialog ask for.
  def self.icon_name = app_id

  # The GSettings schema id and its path. Both are spelled out in
  # data/app.gschema.xml; this is the same derivation that file hardcodes, so a
  # change to BASE_APP_ID is caught by the schema lookup failing rather than by
  # silently reading another app's keys.
  def self.schema_id = BASE_APP_ID
  def self.schema_path = "/#{BASE_APP_ID.tr('.', '/')}/"

  # The installed data directory, or the checkout's data/ when the gem is being
  # run from source. The first candidate that carries app.gschema.xml wins.
  def self.data_dir
    @data_dir ||= data_dir_candidates.find { |dir| File.exist?(File.join(dir, 'app.gschema.xml')) } ||
      checkout_data_dir
  end

  def self.checkout_data_dir = File.expand_path('../data', __dir__)

  def self.data_dir_candidates
    [
      checkout_data_dir,
      *ENV.fetch('XDG_DATA_DIRS', '/usr/local/share:/usr/share')
          .split(File::PATH_SEPARATOR)
          .map { |dir| File.join(dir, BASE_APP_ID) },
    ]
  end

  # Where Gtk::IconTheme is told to look for the seven bundled symbolic icons
  # and the application icons.
  def self.icon_dir = File.join(data_dir, 'icons')

  # Where a locally compiled gschemas.compiled lives, for a checkout that has
  # run `rake schema:compile` but has not installed anything.
  def self.schema_dir = File.join(data_dir, 'schemas')

  def self.locale_dir = File.expand_path('../locale', __dir__)

  def self.ui_path(name) = File.join(data_dir, 'ui', name)

  # Upstream's `GLib.set_application_name("Biblioteca")` (src/bin.js:18), which
  # is the name the shell, the window manager and notifications read.
  def self.set_application_name
    GLib.application_name = NAME
  end

  # Upstream's `pkg.initGettext()` (src/main.js:4). Two domains are bound to
  # the same catalogue: the Ruby one, which `_()` reads, and libintl's, which
  # is what GtkBuilder translates data/ui/shortcuts.ui through and what
  # AppStream and GLib read for the .desktop and the schema.
  def self.init_gettext
    GLib::GetText.bindtextdomain(DOMAIN, locale_dir)
    GetText.bindtextdomain(DOMAIN, path: locale_dir)
  end

  # Including this in a class binds that class to the application's catalogue
  # and gives it `_()`, `n_()`, `p_()` and `N_()` both in the class body (for
  # constants) and in instance methods.
  #
  # GetText.bindtextdomain_to includes GetText into the target, and
  # GetText.included extends it too, which is what makes a `_()` call in a
  # class body resolve.
  module Translatable
    def self.included(base)
      GetText.bindtextdomain_to(base, Package::DOMAIN, path: Package.locale_dir)
    end
  end
end
