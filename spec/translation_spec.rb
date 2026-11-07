# frozen_string_literal: true

require "fileutils"
require "locale"
require "package"

# TP-2 (TRANSLATION_PARITY.md): neither `Package.init_gettext`'s
# `GLib::GetText.bindtextdomain` call nor its `GetText.bindtextdomain` one had
# ever been proven to hand back a translated string — `locale/` did not
# exist and po/ held no `.po`. `po/fr.po` is a real, complete French
# catalogue (all 64 messages po/org.rubygtkproject.Biblioteca.pot carries),
# and this is the check: compile it and confirm `_()` returns the French
# string, not the msgid, once the locale is French — the one thing
# `Package::Translatable` exists to do.
RSpec.describe "French translation", :extra do
  # A class using Package::Translatable exactly as every real lib/*.rb class
  # does, rather than reaching into GetText's internals directly.
  class TranslationProbe
    include Package::Translatable

    def self.main_menu = _("Main Menu")
  end

  before(:all) do
    mo_path = File.join(
      Package.locale_dir,
      "fr",
      "LC_MESSAGES",
      "#{Package::DOMAIN}.mo",
    )
    unless File.exist?(mo_path)
      require "gettext/tools"
      FileUtils.mkdir_p(File.dirname(mo_path))
      GetText::Tools::MsgFmt.run(
        File.expand_path("../po/fr.po", __dir__),
        "-o",
        mo_path,
      )
    end
  end

  it "returns the French string, not the msgid, once the locale is fr" do
    saved_locale = Locale.current
    begin
      Locale.current = "fr"
      expect(TranslationProbe.main_menu).to eq("Menu principal")
    ensure
      Locale.current = saved_locale
    end
  end

  it "falls back to the msgid for a locale with no catalogue" do
    saved_locale = Locale.current
    begin
      Locale.current = "xx"
      expect(TranslationProbe.main_menu).to eq("Main Menu")
    ensure
      Locale.current = saved_locale
    end
  end
end
