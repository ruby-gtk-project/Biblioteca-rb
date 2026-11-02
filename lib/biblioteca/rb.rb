# frozen_string_literal: true

require_relative "rb/version"

module Biblioteca
  # Rb is the gem's namespace, and `require "biblioteca/rb"` is the cheapest
  # entry point: the version and nothing else.
  #
  # It deliberately does not require the application. `exe/biblioteca` requires
  # `biblioteca`, which loads Biblioteca::Application and with it gtk4,
  # adwaita and webkit-gtk; a spec over a pure-computation file
  # (lib/fzy.rb, lib/doc_index.rb) has no use for a display connection, and
  # spec/spec_helper.rb requires this file.
  module Rb
    class Error < StandardError; end
  end
end
