# frozen_string_literal: true

# Wires the checks this port actually has into `rake default`, which upstream
# in effect gets for free from `meson test` + its CI. Each task skips loudly
# rather than silently when its tool is unavailable in the current
# environment, the same shape rakelib/biblioteca.rake's `data:validate` uses —
# a check that quietly does nothing is worse than one that is not run at all.

TEST_DIR = File.join(__dir__, "..", "test")

namespace :drive do
  desc "Drive Biblioteca::Application end-to-end (needs a display; xvfb-run under nix)"
  task :app do
    ruby(File.join(TEST_DIR, "drive_app.rb"))
  end

  desc "Drive a real Sidebar against a synthetic gi-docgen fixture (needs a display)"
  task :sidebar do
    ruby(File.join(TEST_DIR, "drive_sidebar.rb"))
  end

  desc "Drive the installed exe/biblioteca entry point (needs a display)"
  task :biblioteca do
    ruby(File.join(TEST_DIR, "drive_biblioteca.rb"))
  end
end

desc "Run all three UI drivers (needs a display; see rakelib/README or the devshell banner)"
task drive: ["drive:app", "drive:sidebar", "drive:biblioteca"]

desc "Run the RSpec suite, if rspec is loadable"
task :spec_if_available do
  require "rspec/core"
  status = RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])
  unless status.zero?
    abort("rspec reported failures")
  end
rescue LoadError
  puts "SKIPPED: rspec is not loadable in this environment"
end

desc "Run RuboCop, if it is on PATH and actually runnable against this gemset"
task :rubocop_if_available do
  # `which` alone is not enough: a `rubocop` earlier on PATH than this
  # checkout's own may be a wrapper pinned to a *different* project's
  # Gemfile/lockfile (ambient dev tooling, another checkout's devshell, …),
  # which resolves but then fails to find itself registered against that
  # other bundle. `--version` is cheap enough to use as the real probe.
  if system("rubocop --version > /dev/null 2>&1")
    sh("rubocop")
  else
    puts "SKIPPED: no rubocop runnable against this gemset was found on PATH"
  end
end

# Enhances the base `task :default` from the root Rakefile rather than
# replacing it, which is what that task's own comment says other files should
# do. Order matters: fast, offline checks before the three UI drivers, which
# need a display and the longest to run.
task default: [
  :spec_if_available,
  :rubocop_if_available,
  "schema:validate",
  "gettext:check_pot_drift",
  :drive,
]
