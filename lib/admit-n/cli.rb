# frozen_string_literal: true

require 'admit-n'
require 'thor'
require 'yaml'
require 'pathname'

# The actual command line to run
class AdmitN::CLI < Thor

  CONFIG_FILE = '~/.config/admit-n.conf'

  no_commands do
    # Get the location of the configuration file.
    #
    # @return [Pathname]
    #
    def config_file
      path = options[:config] || ENV['ADMIT_N_CONFIG'] || CONFIG_FILE
      Pathname(path).expand_path
    end

    # Load and validate the (YAML) configuration file.
    #
    # @param file [Pathname,#to_s] the file path
    #
    # @return [Hash] the configuration structure
    #
    def load_config file
      file = Pathname(file).expand_path
      raw  = file.exist? ? YAML.safe_load(file.open, symbolize_names: true) : {}
      AdmitN::Types::Config[raw]
    end

    # Recurse through the configuration type
    #
    # @param spec [Dry::Types::Type]
    # @param labels [Hash]
    #
    # @return [Object] the configuration structure
    #
    def config_prompt spec, label: nil, labels: {}

      if spec.respond_to? :keys
        say label if label

        spec.keys.reduce({}) do |hash, key|
          name = key.name
          type = key.type
          lab  = labels[name] || name.to_s

          hash[name] = config_prompt type, label: lab, labels: labels
          hash
        end
      else
        # not a hash
        default = spec.value if spec.default?

        prompt = default ? "#{label} (#{default}): " : "#{label}: "

        begin
          ret = ask "#{label}:", default: default
          spec[ret]
        rescue Dry::Types::ConstraintError
          say_error "Input doesn't match constraint. Try again…"
          retry
        end
      end
    end
  end

  # Parse and validate the configuration
  def initialize(args = [], opts = {}, config = {})
    # warn args.inspect, opts.inspect, config.inspect
    super
    # warn options[:config]
    # @config = load_config config_file
  end

  # no default because we want the right sequence

  class_option :config, aliases: :C, type: :string

  # these are labels for configuration parameteres for when we don't
  # like derived ones
  LABELS = {
    dsn:    'Database DSN',
    host:   'Microservice host',
    port:   'Microservice port',
    jwt:    'JWT parameters',
    secret: 'Secret',
    urls:   'URLs',
  }.freeze

  desc 'init', 'Initialize the state database and configuration file'

  def init
    # if config file exists, ask to overwrite

    file = config_file.expand_path
    ok   = file.exist? ? yes?("#{file} exists. Overwrite?") : true

    if ok
      @config = config_prompt AdmitN::Types::Config,
                              label:  'We need a minimal set of configuration parameters',
                              labels: LABELS

      # write config file
      begin
        file.parent.mkpath
        YAML.safe_dump @config, file.open(?w),
                       permitted_classes: [Symbol], stringify_names: true
      rescue Errno::EACCES => e
        say_error "Could not create #{file}: #{e.message}"
        exit 1
      end
    else
      begin
        @config = YAML.safe_load file.open, symbolize_names: true
      rescue Exception => e
        # XXX tighten this exception
        say_error "Could not load configuration #{file}: #{e.message}"
        exit 1
      end
    end

    # now it should coerce
    begin
      @config = AdmitN::Types::Config[@config]
    rescue Exception => e
      # XXX tighten this exception
      say_error "Configuration does not validate: #{e.message}"
      exit 1
    end

    # connect to database and create tables
    begin
      @state = AdmitN::State.new @config[:dsn], create: false
    rescue Exception => e
      # XXX tighten this exception
      say_error "Can't open database: #{e.message}"
      exit 1
    end

    # overwrite database
    force = @state.initialized? && yes?('Database already exists. Overwrite?')
    begin
      @state.first_run! force: force
    rescue Exception => e
      say_error "Could not initialize database; check manually. (#{e.message})"
      exit 1
    end
  end

  desc 'serve [-C CONFIG] [-Fz]', 'Run the microservice'
  option :host, aliases: ?h, type: :string, default: 'localhost',
    desc: 'Host to listen on'
  option :port, aliases: ?p, type: :numeric, default: 10105,
    desc: 'Port to listen on'
  option :fastcgi, aliases: ?F, type: :boolean, default: false,
    desc: 'Run service as FastCGI rather than ordinary HTTP'
  option :detach, aliases: ?z, type: :boolean, default: false,
    desc: 'Daemonize the process and run in the background'

  def serve
    invoke :init unless config_file.expand_path.exist?

    require 'rack'
    require 'rackup'

    begin
      @config = load_config config_file
    rescue Exception => e
      say_error "Could not load configuration #{config_file}: #{e.message}"
      exit 1
    end

    srvopts = {
      app:       AdmitN::App.new(
        @config[:dsn],
        jwt:  @config[:jwt][:secret],
        urls: @config[:urls],
      ),
      daemonize: options[:detach],
      Host:      options[:host] || @config[:host],
      Port:      options[:port] || @config[:port],
    }
    # apparently the rack people still haven't merged fastcgi into rackup?
    # srvopts[:server] = 'fastcgi' if options[:fastcgi]

    Rackup::Server.start(srvopts)
  end

  default_command :serve
end
