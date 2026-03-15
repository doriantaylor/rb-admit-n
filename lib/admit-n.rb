# frozen_string_literal: true

require 'admit-n/version'
require 'admit-n/driver/stripe'
require 'xml/mixup'
require 'uuid/ncname'

# Admit-_N_ performs order fulfillment for one-off payments for access
# to gated content, where the customer can buy access for themselves
# and/or any number of others.
#
module AdmitN

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
      # generate a nonce to be associated with the checkout session

      # mint a new checkout session

      # redirect to uri
    end

    # Receive the redirection from stripe
    #
    # @param req [Rack::Request] the request object
    #
    # @return [Rack::Response] the response
    #
    def checkout_landing req
      # return 405 unless the method is GET
      #
      # get the nonce and the checkout session id

      # only if we have beaten the webhook:
      # * call out to API to verify payment success
      #   (return 503 if reaching out to stripe fails)
      # * enroll customer to auth database

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

      # return 401 if no stripe signature header

      # return 403 if stripe signature is bad

      # return 409 if payload is invalid

      # return 202 if we don't handle this payload

      # on `checkout.session.success`:
      # only if we have beaten the landing page:
      # * receive payment success notification
      # * enroll customer into auth database

      # on `checkout.session.expired`:
      # * invalidate the nonce associated with the checkout session

      # return 204 no content
    end

    public

    def initialize
    end

    def call env
      # surgery to normalize https
      if scheme = env['REQUEST_SCHEME']
        env['HTTPS'] = 'on'.freeze if scheme.strip.downcase == 'https'
      end

      req  = Rack::Request.new env
      resp = Rack::Response[404]

      begin
        # resp =
      end

      resp
    end
  end
end
