# frozen_string_literal: true

# Config for development dependencies of this library
# i.e., not configured by this library
#
# SimpleCov & related config (must run BEFORE any other requires)
# NOTE: Gemfiles for non-coverage appraisals may not have kettle-soup-cover.
#       The rescue LoadError handles that scenario.
begin
  require "kettle-soup-cover"
  if Kettle::Soup::Cover::DO_COV
    # Requiring simplecov loads the project-local `.simplecov`.
    require "simplecov"
    require "kettle/soup/cover/config"
    SimpleCov.start
  end
rescue LoadError => error
  # check the error message and re-raise when unexpected
  unless error.message.include?("kettle")
    raise error
  end
end

# External RSpec & related config
#
# The kettle-dev bundle at the repo root has this; the Nix dev shell does not,
# because nix/Gemfile carries the app's runtime gems only and kettle-test pulls
# a whole development stack behind it. The suite itself is plain RSpec, so a
# missing harness costs nothing but the extra helpers in spec/README.md, and
# running `ruby -e 'RSpec::Core::Runner.run(...)'` from the dev shell — which is
# the command that shell's banner prints — has to work.
begin
  require "kettle/test/rspec"
  # `kettle/test/rspec` installs harness helpers documented in spec/README.md.
rescue LoadError => error
  # check the error message and re-raise when unexpected
  unless error.message.include?("kettle")
    raise error
  end
end

# This library
require "biblioteca/rb"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
