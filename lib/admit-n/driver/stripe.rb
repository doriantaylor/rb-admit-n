require 'admit-n/driver'
require 'stripe'

# Payment processor driver for Stripe.
#
class AdmitN::Driver::Stripe < AdmitN::Driver

  # 
  def initiate req
    # generate a nonce to be associated with the checkout session

    # mint a new checkout session

    # redirect to uri
  end

  # Validate the request redirected
  def collector req
    #
    # get the nonce and the checkout session id

    # only if we have beaten the webhook:
    # * call out to API to verify payment success
    #   (return 503 if reaching out to stripe fails)
    # * enroll customer to auth database
  end

  # Handle miscellaneous Web hook events.
  #
  # @raise [AdmitN::ErrorResponse]
  #
  # @return [Rack::Response]
  #
  def webhook req
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
end
