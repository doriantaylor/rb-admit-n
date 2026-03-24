# frozen_string_literal: true

require_relative 'version'
require 'pathname'
require 'dry-schema'
require 'uuidtools'

# This is a type coercion bundle for Admit-N.
module AdmitN::Types
  include Dry::Types()

  # lol how many times am i going to make this thing
  Path = Instance(Pathname).constructor { |s| Pathname(s).expand_path }

  # ok uuid type
  UUID = Instance(UUIDTools::UUID).constructor do |x|
    return x if x.is_a? UUIDTools::UUID
    m = /\A(?:urn:uuid:)?(\h{8}(?:-\h{4}){4}\h{8})\Z/i.match x.to_s
    raise ArgumentError, "#{x} is a valid UUID" unless m
    UUIDTools::UUID.parse m.captures.first
  end

  # json type (is there one already?) which has to union all the primitives
  # JSONb = JSON::Nil | JSON::
  # JSONb = Types::Constructor
end
