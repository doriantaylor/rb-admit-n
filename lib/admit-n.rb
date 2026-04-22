# frozen_string_literal: true

require 'admit-n/types'
require 'admit-n/state'
require 'admit-n/driver/stripe'
require 'xml/mixup'
require 'uuid/ncname'

require 'rack/request'
require 'rack/response'


# Admit-_N_ performs order fulfillment for one-off payments for access
# to gated content, where the customer can buy access for themselves
# and/or any number of others. "Order fulfillment", in this case,
# refers to enrolling a certain number of seats
#
module AdmitN

  # An error response (with status, headers, etc) that can be raised
  # and caught.
  class ErrorResponse < RuntimeError

    attr_reader :response

    # Create a new error response.
    #
    # @param body [#to_s, #each] the response body
    # @param status [Integer] the HTTP status code
    # @param headers [Hash] the header set
    #
    def initialize body = nil, status = 500, headers = {}
      if body.is_a? Rack::Response
        @response = body
      else
        @response = Rack::Response.new body, status, headers
      end
    end

    # Returns the error message (which is the response body).
    #
    # @return [String] the error message (response body)
    #
    def message
      @response.body
    end

    # Sets a new error message (response body). Does not change
    # anything else, like headers or status or anything.
    #
    # @param msg [#to_s] the new error message
    #
    def message= msg
      # XXX this is actually wrong and will crash
      @response.body = msg.to_s
    end

    # Generate a new exception with a Rack::Response as a message.
    # Otherwise creates a new error response.
    #
    # @param message [Rack::Response, #to_s] the response object or string
    #
    # @return [ForgetPasswords::ErrorResponse] a new error response
    #
    def self.exception message
      # XXX TODO auto generate (x)html from text message?
      case message
      when Rack::Response then self.new message
      else
        self.new message.to_s, 500, { 'Content-Type' => 'text/plain' }
      end
    end

    # Returns itself if the message is nil. Otherwise it runs the
    # class method with the message as its argument.
    #
    # @param message [nil, Rack::Response, #to_s] optional response
    #  object or string
    #
    # @return [ForgetPasswords::ErrorResponse] a new error response
    #
    def exception message = nil
      return self if message.nil?
      self.class.exception message
    end
  end

  # This part is the actual Web application.
  #
  class App
    include XML::Mixup

    private

    # Set up the checkout session and redirect.
    #
    # @param req [Rack::Request] the request object
    #
    # @return [Rack::Response] the response
    #
    def forward_to_checkout req
      # if we aren't being forced, determine if the user is logged in
      # or if the email supplied is a customer or beneficiary

      begin
        driver.initiator req
      rescue AdmitN::ErrorResponse => e
      end
    end

    # Receive the redirection from stripe
    #
    # @param req [Rack::Request] the request object
    #
    # @return [Rack::Response] the response
    #
    def checkout_landing req
      # return 405 unless the method is GET

      uri = req_uri req

      principal = driver.validate uri

      # obtain session cookie?

      # redirect to assign/confirm
    end

    # Dummy service resource that redirects a freshly logged-in user
    # to the "lobby" depending on who they are:
    #
    # * if they are part of the audience then they go to the content
    # * otherwise they are an account manager
    #
    # @param req [Rack::Request] the request object
    #
    # @return [Rack::Response] the response
    #
    def forward_to_content req
      # return 405 unless request is a GET
      # return 401 unless there is a `REMOTE_USER`

      # uhh we need a target to redirect to
    end

    # Display the available/assigned slots. This may be something that
    # gets transcluded into another resource.
    #
    # @param req [Rack::Request] the request object
    #
    # @return [Rack::Response] the response
    #
    def display_slots req
      # return 405 unless request is a GET or POST
      # return 401 unless there is a `REMOTE_USER`

      # return 403 unless user is authenticated as the customer or
      # assignee who can grant additional slots

      # maybe we should split between POST and GET

      # POST is just gonna be like a vanilla assign your slot kinda thing

      # GET is gonna be the actual table
      # (do we want a json variant?)

      # add a "buy more" button if the user is also the customer and
      # there are two or more slots
    end

    # Receive asynchronous messages (from Stripe) through a Web hook.
    #
    # @note Stripe attempts to retry on an exponential back-off
    #  schedule if they don't get a `2XX` response code.
    #
    # @param req [Rack::Request] the request object
    #
    # @return [Rack::Response] the response
    #
    def handle_webhook req
      # return 405 if request method is other than POST

      # return 415 if content type is not json

      driver.webhook req
    end

    # This is all going to be replaced with Handler Manifest Protocol
    # (when I finally sit down and design it), but the URL paths are
    # specified in the config file and I wanted to put a second layer
    # of indirection there between the configuration keys and the
    # method names.
    #
    METHODS = {
      initial_cta:    :forward_to_checkout,
      already_in:     :sanity_check,
      post_checkout:  :checkout_landing,
      assign_confirm: :display_slots,
      webhook:        :handle_webhook,
    }

    public

    attr_reader :state, :driver

    # Initialize the app.
    #
    # @param state [AdmitN::State, #to_s] DSN or database wrapper instance
    # @param driver [Hash] Driver instance or spec
    # @param jwt [String] JWT secret
    # @param endpoints [Hash<Symbol, String>] Authentication service endpoints
    # @param urls [Hash<Symbol, String>] URLs to resources under management
    #
    # @return [void]
    #
    def initialize state, jwt: nil, urls: AdmitN::Types::URLConfig.value, endpoints: {}
      @state     = state.is_a?(AdmitN::State) ? state : AdmitN::State.new(state)
      @endpoints = endpoints
      @urls      = urls
      @mapping   = @urls.invert
    end

    # Return an absolute request-URI from the Rack::Request.
    #
    # @param req [Rack::Request] the request object
    #
    # @return [URI] the full URI.
    #
    def req_uri req
      URI(req.base_url) + req.env['REQUEST_URI']
    end

    # Call the app through the {Rack} interface.
    #
    # @param env [Hash] the Rack environment
    #
    # @return [Array] the noramlized Rack response
    #
    def call env
      # surgery to normalize https
      if scheme = env['REQUEST_SCHEME']
        env['HTTPS'] = 'on' if scheme.strip.downcase == 'https'
      end

      req  = Rack::Request.new env
      resp = Rack::Response[404]
      uri  = req_uri req

      # this is the method we call
      meth = @mapping[uri.path] or return resp

      begin
        resp = send meth, req
      rescue AdmitN::ErrorResponse => e
        resp = e.response
      end

      resp.finish
    end
  end
end
