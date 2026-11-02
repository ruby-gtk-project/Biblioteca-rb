# frozen_string_literal: true

# Installs the data/ tree and maintains the message catalogue.
#
# These tasks stand in for upstream's data/meson.build and src/meson.build,
# which configure_file() the four templates with meson's `app_id` and install
# them, compile the GSettings schema, and install the icons.
#
# Here data/app.desktop, data/app.service, data/app.metainfo.xml and
# data/app.gschema.xml are already substituted — the port has one app id, not a
# meson option — so installing is a copy under the id-derived basename that
# each tool looks for.

require "fileutils"

APP_ID = "org.rubygtkproject.Biblioteca"
DATA_DIR = File.join(__dir__, "..", "data")
PO_DIR = File.join(__dir__, "..", "po")

def install_prefix
  ENV.fetch("PREFIX", File.join(Dir.home, ".local"))
end

def install_file(source, dir, basename)
  FileUtils.mkdir_p(dir)
  File.join(dir, basename).tap do |target|
    FileUtils.cp(source, target)
    puts "installed #{target}"
  end
end

namespace :schema do
  desc "Compile data/app.gschema.xml into data/schemas for an uninstalled checkout"
  task :compile do
    File.join(DATA_DIR, "schemas").tap do |dir|
      FileUtils.mkdir_p(dir)
      FileUtils.cp(
        File.join(DATA_DIR, "app.gschema.xml"),
        File.join(dir, "#{APP_ID}.gschema.xml"),
      )
      sh("glib-compile-schemas", "--strict", dir)
    end
  end

  desc "Validate data/app.gschema.xml without writing anything"
  task :validate do
    sh(
      "glib-compile-schemas",
      "--strict",
      "--dry-run",
      DATA_DIR,
    )
  end
end

namespace :data do
  desc "Install the desktop entry, metainfo, D-Bus service, schema and icons under PREFIX"
  task install: ["data:desktop", "data:metainfo", "data:service", "data:schema", "data:icons"]

  task :desktop do
    install_file(
      File.join(DATA_DIR, "app.desktop"),
      File.join(install_prefix, "share", "applications"),
      "#{APP_ID}.desktop",
    )
  end

  task :metainfo do
    install_file(
      File.join(DATA_DIR, "app.metainfo.xml"),
      File.join(install_prefix, "share", "metainfo"),
      "#{APP_ID}.metainfo.xml",
    )
  end

  # Upstream's data/app.service carries @bindir@; the only substitution left to
  # make is the directory the `biblioteca` executable landed in.
  task :service do
    File.join(
      install_prefix,
      "share",
      "dbus-1",
      "services",
    ).tap do |dir|
      FileUtils.mkdir_p(dir)
      File.join(dir, "#{APP_ID}.service").tap do |target|
        File.write(
          target,
          File.read(File.join(DATA_DIR, "app.service"))
              .gsub("@bindir@", File.join(install_prefix, "bin")),
        )
        puts "installed #{target}"
      end
    end
  end

  task :schema do
    install_file(
      File.join(DATA_DIR, "app.gschema.xml"),
      File.join(
        install_prefix,
        "share",
        "glib-2.0",
        "schemas",
      ),
      "#{APP_ID}.gschema.xml",
    )
    sh(
      "glib-compile-schemas",
      File.join(
        install_prefix,
        "share",
        "glib-2.0",
        "schemas",
      ),
    )
  end

  task :icons do
    File.join(install_prefix, "share", "icons").tap do |dir|
      FileUtils.mkdir_p(dir)
      FileUtils.cp_r(File.join(DATA_DIR, "icons", "hicolor"), dir)
      puts "installed #{File.join(dir, "hicolor")}"
    end
  end

  desc "Validate the installed-file templates with the freedesktop tools, when present"
  task :validate do
    if system("which desktop-file-validate > /dev/null 2>&1")
      sh("desktop-file-validate", File.join(DATA_DIR, "app.desktop"))
    end
    if system("which appstreamcli > /dev/null 2>&1")
      sh(
        "appstreamcli",
        "validate",
        "--override=release-time-missing=info",
        "--no-net",
        File.join(DATA_DIR, "app.metainfo.xml"),
      )
    end
  end
end

namespace :gettext do
  desc "Regenerate po/#{APP_ID}.pot from po/POTFILES.in"
  task :pot do
    ruby File.join(
      __dir__,
      "..",
      "po",
      "extract.rb",
    )
  end

  desc "Compile po/*.po into locale/<lang>/LC_MESSAGES/#{APP_ID}.mo"
  task :mo do
    require "gettext/tools"
    Dir.glob(File.join(PO_DIR, "*.po")).each do |po|
      File.basename(po, ".po").then do |lang|
        File.join(
          __dir__,
          "..",
          "locale",
          lang,
          "LC_MESSAGES",
        ).tap do |dir|
          FileUtils.mkdir_p(dir)
          GetText::Tools::MsgFmt.run(po, "-o", File.join(dir, "#{APP_ID}.mo"))
        end
      end
    end
  end
end
