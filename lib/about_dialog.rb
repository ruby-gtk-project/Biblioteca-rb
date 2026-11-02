# frozen_string_literal: true

require 'adwaita'

require_relative 'biblioteca/rb/version'
require_relative 'package'

# AboutDialog is the About Biblioteca dialog.
#
# A direct port of upstream's src/about.js, with the same metadata, the same
# credit list and the same Contributors section it adds by hand. The version
# comes from this gem rather than from pkg.version, and the application icon is
# Package.icon_name, which is the id the port registers under and the basename
# of the icon data/icons/hicolor installs.
class AboutDialog
  include Package::Translatable

  APPLICATION_NAME = 'Biblioteca'
  DEVELOPER_NAME = 'Akshay Warrier'
  COPYRIGHT = '© 2024 Akshay Warrier'
  WEBSITE = 'https://biblioteca.sonny.re'
  ISSUE_URL = 'https://biblioteca.sonny.re/feedback'

  DEVELOPERS = [
    'Akshay Warrier https://github.com/AkshayWarrier',
    'Sonny Piers https://sonny.re',
  ].freeze

  ARTISTS = ['Jakub Steiner https://jimmac.eu'].freeze

  CONTRIBUTORS = [
    'Sunniva Løvstad https://turtle.garden',
    'José Hunter https://github.com/halfmexican',
  ].freeze

  def initialize(app)
    @app = app
  end

  # Upstream presents the dialog over the application's active window, and
  # builds a fresh one on every activation of app.about.
  def present
    dialog.tap { |d| d.present(@app.active_window) }
  end

  def dialog
    Adwaita::AboutDialog.new.tap do |d|
      d.application_name = APPLICATION_NAME
      d.developer_name = DEVELOPER_NAME
      d.copyright = COPYRIGHT
      d.license_type = :gpl_3_0_only
      d.version = Biblioteca::Rb::VERSION
      d.website = WEBSITE
      d.application_icon = Package.icon_name
      d.issue_url = ISSUE_URL
      d.developers = DEVELOPERS
      d.artists = ARTISTS
      d.add_credit_section(_('Contributors'), CONTRIBUTORS)
    end
  end
end
