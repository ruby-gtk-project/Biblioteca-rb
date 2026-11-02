# frozen_string_literal: true

require 'adwaita'

require_relative 'biblioteca/rb/version'

# AboutDialog is the About Biblioteca dialog.
#
# A direct port of upstream's src/about.js, with the same metadata, the same
# credit list and the same Contributors section it adds by hand. The version
# comes from this gem rather than from pkg.version, and the application icon
# follows the application id the port registers under.
class AboutDialog
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
      d.application_icon = @app.application_id
      d.issue_url = ISSUE_URL
      d.developers = DEVELOPERS
      d.artists = ARTISTS
      d.add_credit_section('Contributors', CONTRIBUTORS)
    end
  end
end
