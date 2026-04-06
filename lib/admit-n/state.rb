# frozen_string_literal: true
require_relative 'types'
require 'sequel'
require 'money'

# this needs to record which customer bought how many of which product
# (and when), the quantity of audience slots per transaction, and
# assignees to those slots
class AdmitN::State
  # vendor-specific bundles

  # This is the vendor-specific bundle for PostgreSQL.
  module Pg
    # make sure pgcrypto is installed
    # db.after_connect { |c| c.execute 'CREATE EXTENSION IF NOT EXISTS pgcrypto' }

    # warn 'loaded module'

    private

    # Wraps the body of a PL/PGSQL trigger function in boilerplate.
    #
    # @note don't forget the return value.
    #
    # @param name [#to_s] the (PostgreSQL) function name
    # @param body [#to_s] the body (`DECLARE`…`BEGIN`…`END;`)
    #
    # @return [String] the complete function
    #
    def trigger_func name, body = nil, &block
      # body can be an arg or a block
      body ||= block.call

      # said boilerplate
      <<~EOQ
      CREATE OR REPLACE FUNCTION #{name.to_s}() RETURNS TRIGGER AS $trigger$
      #{body.to_s}
      $trigger$ LANGUAGE plpgsql
      EOQ
    end

    def create_trigger table, fname, function = nil, name: nil, &block
      # wrap the function body
      function = trigger_func(fname, function || block.call)

      # derive the trigger name from the function name
      name ||= "t_#{fname}"

      # now (re)create the trigger
      db.run function
      db.run "DROP TRIGGER IF EXISTS #{name} ON #{table}"
      # XXX we should probably consider where the heck we want the trigger
      db.run <<~EOQ
        CREATE TRIGGER #{name} BEFORE INSERT ON #{table}
        FOR EACH ROW EXECUTE FUNCTION #{fname}()
      EOQ
    end

    def inject_types!
      gen = db.create_table_generator

      gen.class.instance_exec do
        # proper uuid type
        define_method :UUID do |name, opts=OPTS|
          column name, :uuid,
            { default: Sequel.function(:gen_random_uuid) }.merge(opts)
        end

        define_method :Money do |name, opts=OPTS|
          column name, Integer, opts
        end

        define_method :Currency do |name, opts=OPTS|
          column name, String, opts.merge(size: 3)
        end

        # proper jsonb type
        define_method :JSON do |name, opts=OPTS|
          column name, :jsonb, opts
        end
      end
      # warn "ran types"
    end

    def create_triggers!
      # proper triggers
      # warn "ran triggers"
      create_trigger :assignment, :ensure_purchase_quantity do
        <<~EOQ
        begin
          if (select count(*) from tg_table_name where purchase = new.purchase)
            >= (select quantity from purchase where id = new.purchase)
            then raise exception
              'assignment limit reached for purchase %', new.purchase;
          end if;
          return new;
        end;
        EOQ
      end
    end
  end

  # This is the vendor-specific bundle for MySQL.
  module MySQL
    # fake uuid type

    # uuid check constraint

    # triggers to the extent we can
  end

  # This is the vendor-specific bundle for SQLite.
  module SQLite
    # apparently foreign keys aren't asserted
    # db.after_connect { |c| c.execute 'PRAGMA foreign_keys = ON' }

    # fake uuid type

    # uuid check constraint (to the extent we can)

    # triggers to the extent we can
  end

  private

  # def inject_types!
  # end

  # def create_triggers!; end

  VENDOR_MAP = {
    postgres: Pg,
    mysql:    MySQL,
    sqlite:   SQLite,
  }
  VENDOR_MAP[:mysql2] = VENDOR_MAP[:mysql]

  S = Sequel

  # spec for generating table classes
  # * `class` (if it can't be inferred) is the class name (or stack of names)
  # * `model` is relations, table-specific methods etc
  # * `create` is what gets used to create the table
  TABLES = {
    product: {
      model: -> {
        one_to_many :purchase

        # Retrieve the price
        def price
          ::Money.new price_raw, currency
        end

        # Set the price
        def price= price
          price_raw = price.fractional
          currency  = price.currency.code.upcase
        end
      },
      create: -> {
        # our identifier
        UUID :id, null: false, primary_key: { name: :pk_product }
        # remote identifier
        String :remote_id, null: false, text: true
        # text description
        String :description, null: false, text: true, default: ''
        # price
        Money :price_raw, null: false
        # currency
        Currency :currency, null: false, default: 'USD'
        # added on
        Time :added, null: false, default: S::CURRENT_TIMESTAMP

        constraint(:ck_product_currency) { currency =~ trim(upper(currency)) }
      },
    },
    customer: {
      model: -> {
        one_to_many :purchase
      },
      create: -> {
        # our identifier
        UUID :id, null: false, primary_key: { name: :pk_customer }
        # remote identifier
        String :remote_id, null: false, text: true
        # email
        String :email, null: false, text: true
        # added on
        Time :added, null: false, default: S::CURRENT_TIMESTAMP
      },
    },
    event_log: {
      # i dunno, we could probably infer this lol
      class: %i[Event Log],
      model: -> {
        # is there anything in here??
      },
      create: -> {
        # our identifier
        UUID :id, null: false, primary_key: { name: :pk_event_log }
        # recorded on
        Time :logged, null: false, default: S::CURRENT_TIMESTAMP
        # passive (is webhook?)
        # message type
        # message (jsonb)
        JSON :message, null: false
      },
    },
    purchase: {
      model: -> {
        one_to_one  :event_log
        many_to_one :product
        many_to_one :customer
        one_to_many :assignment
      },
      create: -> {
        # our identifier
        UUID :id, null: false, default: nil, primary_key: { name: :pk_purchase }
        # customer
        UUID :customer, null: false, default: nil
        # product
        UUID :product, null: false, default: nil
        # quantity
        Integer :quantity, null: false, default: 1
        # remote identifier
        String :remote_id, null: false, text: true
        # executed at
        Time :executed, null: false
        # logged at
        Time :logged, null: false, default: S::CURRENT_TIMESTAMP

        constraint(:ck_purchase_quantity) { quantity > 0 }

        foreign_key %i[id],       :event_log, name: :fk_purchase_event
        foreign_key %i[customer], :customer,  name: :fk_purchase_customer
        foreign_key %i[product],  :product,   name: :fk_purchase_product
      },
    },
    assignment: {
      model: -> {
        many_to_one :purchase
      },
      create: -> {
        # purchase
        UUID :purchase, null: false, default: nil
        # email
        String :email, null: false, text: true
        # assigned at
        Time :assigned, null: false, default: S::CURRENT_TIMESTAMP

        primary_key %i[purchase email], name: :pk_assignment
      },
    },
  }

  # Generate the {Sequel::Model} classes associated with their
  # respective datasets. Optionally (re)create the tables.
  #
  # @param force [false, true] whether to force table creation.
  #
  # @return [void]
  #
  def first_run! force: false
    # only run this if forced or not all the tables are present
    create_tables force: force if !inititalized? || force

    me = root = self.class

    TABLES.each do |table, struct|
      # give me a stack of class names
      cnames = struct[:class] || table.to_s.capitalize.to_sym
      # warn cnames.inspect
      cnames = cnames.is_a?(Array) ? cnames.dup : [cnames]

      cls  = nil
      root = self.class
      until cnames.empty?
        slug = cnames.shift
        if root.const_defined? slug
          cls = root.const_get slug
        else
          # create the new class
          cls = cnames.empty? ? Class.new(Sequel::Model(db[table])) : Module.new
          # add to root
          root.const_set slug, cls

          # do model stuff i guess
          cls.instance_exec(&struct[:model]) if struct[:model]
        end

        # now assign root
        root = cls
      end

      # make this thing addressable lol
      instance_variable_set "@#{table}", cls
    end
  end

  public

  attr_reader :db, *TABLES.keys

  # Instantiate the state object.
  #
  # @param dsn [String] the data source name
  # @param create [true, false, :force] whether to create (or force
  #  the re-creation) of the database tables
  #
  # @return [void]
  #
  def initialize dsn, create: true, logger: nil
    @db = Sequel.connect dsn, logger: logger

    force = create == :force

    # attempt to load scheme-specific module
    mod = VENDOR_MAP[@db.adapter_scheme] or raise NotImplementedError,
      "No support for scheme #{@db.adapter_scheme}."
    self.class.include mod

    first_run! force: force if create
  end

  def initialized?
    # if this is empty then the db has the tables
    (TABLES.keys - db.tables).empty?
  end

  # Create the tables in the database.
  #
  # @param force [false, true]
  #
  # @return [void]
  #
  def create_tables force: false
    # we want our types so the create statements actually work
    inject_types! if respond_to? :inject_types!, true

    # anyway…
    method  = 'create_table' + (force ? ?! : ??)
    cascade = force and db.adapter_scheme != :sqlite

    TABLES.keys.each do |table|
      proc = TABLES[table][:create]
      db.drop_table table, cascade: cascade if force and db.table_exists?(table)
      db.send method, table, &proc
    end

    # add any triggers to the database
    create_triggers! if respond_to? :create_triggers!, true

    true
  end

  # Return a less-cluttered representation of the object.
  #
  # @return [String] A human-readable representation of the object.
  #
  def inspect
    "<#{self.class.name} db=#{db.url}>"
  end

  def record_sale
  end
end
