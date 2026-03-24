# frozen_string_literal: true

require 'admit-n'
require 'thor'

# The actual command line to run
class AdmitN::CLI < Thor

  no_commands do
    def load_config file
    end
  end

  # Parse and validate the configuration
  def initialize(args = [], opts = {}, config = {})
    # warn args.inspect, opts.inspect, config.inspect
    super
    warn options[:config]
    @config = load_config nil
  end

  class_option :config, aliases: :C, type: :string,
    default: "~/.config/admit-n.conf"

  desc 'init', 'Initialize the state database'

  def init
  end

  desc 'serve [-C CONFIG] [-Fz]', 'Run the microservice'
  option :host, aliases: ?h, type: :string, default: 'localhost'.freeze,
    desc: 'Host to listen on'
  option :port, aliases: ?p, type: :numeric, default: 10105,
    desc: 'Port to listen on'
  option :fastcgi, aliases: ?F, type: :boolean, default: false,
    desc: 'Run service as FastCGI rather than ordinary HTTP'
  option :detach, aliases: ?z, type: :boolean, default: false,
    desc: 'Daemonize the process and run in the background'

  def serve
    require 'rack'
    require 'rackup'

    srvopts = {
      app:       AdmitN::App.new,
      daemonize: options[:detach],
      Host: options[:host] || @config[:host],
      Port: options[:port] || @config[:port],
    }
    # apparently the rack people still haven't merged fastcgi into rackup?
    # srvopts[:server] = 'fastcgi' if options[:fastcgi]

    Rackup::Server.start(srvopts)
  end

  default_command :serve
end
