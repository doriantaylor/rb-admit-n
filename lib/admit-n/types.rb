# frozen_string_literal: true

require_relative 'version'
require 'dry-schema'
require 'uuidtools'
require 'pathname'

# monkey-patch copied almost verbatim from `forget-passwords`
module Dry::Types::Builder
  unless method_defined? :hash_default
    def hash_default
      # obtain all the required keys from the spec
      reqd = keys.select(&:required?)

      if reqd.empty?
        # there aren't any required keys, but we'll set the empty hash
        # as a default if there exist optional keys, otherwise any
        # default will interfere with input from upstream.
        return default({}.freeze) unless keys.empty?
      elsif reqd.all?(&:default?)
        # similarly, we only set a default if all the required keys have them.
        return default(reqd.map { |k| [k.name, k.value] }.to_h.freeze)
        # XXX THIS WILL FAIL IF THE DEFAULT IS A PROC; THE FAIL IS IN DRY-RB
      end

      # otherwise just return self
      self
    end
  end
end

# This is a type coercion bundle for Admit-N.
module AdmitN::Types
  include Dry::Types()

  private # rubocop:disable Style/UselessAccessModifier

  # hostname
  HN_RE = /^(?:[0-9a-z-]+(?:\.[0-9a-z-]+)*|[0-9a-f]{,4}(?::[0-9a-f]{,4}){,7})$/i

  # dsn
  DSN_RE = %r{\A(?<adapter>[a-z][a-z0-9+\-.]+)://
  (?:(?<username>[^:@/]*)(?::(?<password>[^@/]*))?@)?
  (?<host>[^:/?#]*)(?::(?<port>\d+))?
  (?:/(?<database>[^?#]*))?(?:\?(?<query>[^#]*))?\z}xi

  public # rubocop:disable Style/UselessAccessModifier

  Hostname = Coercible::String.constructor(&:strip).constrained(format: HN_RE)

  DSN = Coercible::String.constructor(&:strip).constrained format: DSN_RE

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

  NormSym = Symbol.constructor do |k|
    k.to_s.strip.downcase.tr_s(' _-', ?_).to_sym
  end

  # symbol hash
  SymbolHash = Hash.schema({}).with_key_transform do |k|
    NormSym.call k
  end

  # apparently you can't go from schema to map
  SymbolMap = Hash.map NormSym, Any

  URLConfig = SymbolHash.schema({
    initial_cta:    '/buy_now',
    already_in:     '/existing-customer',
    post_checkout:  '/fulfill-order',
    assign_confirm: '/assign-seats',
    webhook:        '/handle-events',
  }.transform_values { |x| Coercible::String.default x.freeze }).hash_default

  Config = SymbolHash.schema({
    dsn:        DSN,
    host?:      Hostname.default('localhost'),
    port?:      Coercible::Integer.default(10105),
    jwt_secret: Coercible::String.constrained(min_size: 1),
    urls:       URLConfig,
  }).hash_default
end
