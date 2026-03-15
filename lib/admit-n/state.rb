# frozen_string_literal: true
require_relative 'version'
require 'sequel'

# this needs to record which customer bought how many of which product
# (and when), the quantity of audience slots per transaction, and
# assignees to those slots
class AdmitN::State
  private

  S = Sequel

  # we need customer, product, order, seat assignment

  # seat: order, 

  public

  def record_sale
  end
end
