# frozen_string_literal: true

require 'admit-n/version'
require 'pathname'
require 'dry-schema'

module AdmitN::Types
  include Dry::Types()

  # lol how many times am i going to make this thing
  Path = Instance(Pathname).constructor { |s| Pathname(s).expand_path }
end
