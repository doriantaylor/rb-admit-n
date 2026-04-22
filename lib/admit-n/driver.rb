module AdmitN

  # This is the generic driver stub for Admit-N payment processors.
  #
  class Driver
    # Initialize the driver
    #
    # @param state [AdmitN::State] The database object
    # @apram config [Hash<Symbol, Object>] arbitrary configuration parameters
    #
    # @return [void]
    #
    def initialize state, **config
      # XXX we don't know yet if we are going to need elements from
      # the app or just a database handle
      @state = state
    end

    attr_reader :state
  end
end
