require 'money'
require 'open-uri'
require_relative 'on_time_patch'

# Money class, see http://github.com/RubyMoney/money
class Money

  # Provides classes that aid in the ability of exchange one currency with
  # another.
  module Bank
    # Exception that will be thrown if jsonrates.com api returns error on api request.
    class RequestError < StandardError ; end

    # Exception that will be thrown if access_key was not specified.
    class AccessError < StandardError
      # Default message.
      def message
        "Blank access_key! You should get your api access_key on currencylayer.com and specify it"
      end
    end

    # Money::Bank implementation that gives access to the current exchange rates using jsonrates.com api.
    class Currencylayer < Money::Bank::VariableExchange
      include OnTimePatch

      # Host of service jsonrates
      SERVICE_HOST = "apilayer.net"

      # Relative path of jsonrates api
      SERVICE_PATH = "/api/live"

      # accessor of access_key of jsonrates.com service
      attr_accessor :access_key

      class << self
        # @return [Integer] Returns the Time To Live (TTL) in seconds.
        attr_reader :ttl_in_seconds

        # @return [Time] Returns the time when the rates expire.
        attr_reader :rates_expiration

        # @return [Boolean] Returns is Rates Careful mode set.
        attr_reader :rates_careful

        ##
        # Set Rates Careful mode
        #
        # @param [Boolean] value - mode Careful, if set - don't reload cache if get some exception
        def rates_careful= value
          @rates_careful = !!value
        end

        ##
        # Set the Time To Live (TTL) in seconds.
        #
        # @param [Integer] value - the seconds between an expiration and another.
        def ttl_in_seconds= value
          @ttl_in_seconds = value
          refresh_rates_expiration! if ttl_in_seconds
        end

        ##
        # Set the rates expiration TTL seconds from the current time.
        #
        # @return [Time] The next expiration.
        def refresh_rates_expiration!
          @rates_expiration = Time.now + ttl_in_seconds
        end
      end

      ##
      # Clears all rates stored in @rates
      #
      # @return [Hash] The empty @rates Hash.
      #
      # @example
      #   bank = Money::Bank::Currencylayer.new  #=> <Money::Bank::Currencylayer...>
      #   bank.get_rate(:USD, :EUR)  #=> 0.776337241
      #   bank.flush_rates           #=> {}
      def flush_rates
        @store = self.store.class.new
      end

      ##
      # Clears the specified rate stored in @rates.
      #
      # @param [String, Symbol, Currency] from Currency to convert from (used
      #   for key into @rates).
      # @param [String, Symbol, Currency] to Currency to convert to (used for
      #   key into @rates).
      #
      # @return [Float] The flushed rate.
      #
      # @example
      #   bank = Money::Bank::Currencylayer.new    #=> <Money::Bank::Currencylayer...>
      #   bank.get_rate(:USD, :EUR)    #=> 0.776337241
      #   bank.flush_rate(:USD, :EUR)  #=> 0.776337241
      def flush_rate(from, to)
        rates = {}

        self.store.transaction {
          self.store.each_rate do |iso_from, iso_to, rate|
            next if iso_from == from && iso_to == to

            rates[rate_key_for(iso_from, iso_to)] = rate
          end
        }

        @store = self.store.class.new

        self.store.transaction do
          rates.each do |k, r|
            key_from = k.split(self.store.class::INDEX_KEY_SEPARATOR).first
            key_to = k.split(self.store.class::INDEX_KEY_SEPARATOR).last
            self.store.add_rate(key_from, key_to, r)
          end
        end
      end

      ##
      # Returns the requested rate.
      #
      # It uses +#get_rate_careful+ or +#get_rate_straight+ respect of @rates_careful value
      #
      # @param [String, Symbol, Currency] from Currency to convert from
      # @param [String, Symbol, Currency] to Currency to convert to
      #
      # @return [Float] The requested rate.
      #
      # @example
      #   bank = Money::Bank::Currencylayer.new  #=> <Money::Bank::Currencylayer...>
      #   bank.get_rate(:USD, :EUR)  #=> 0.776337241
      def get_rate(from, to)
        if self.class.rates_careful
          get_rate_careful(from, to)
        else
          get_rate_straight(from, to)
        end
      end

      # Registers a conversion rate and returns it (uses +#set_rate+).
      #
      # @param [Currency, String, Symbol] from Currency to exchange from.
      # @param [Currency, String, Symbol] to Currency to exchange to.
      # @param [Numeric] rate Rate to use when exchanging currencies.
      #
      # @return [Numeric]
      #
      # @example
      #   bank = Money::Bank::Currencylayer.new  #=> <Money::Bank::Currencylayer...>
      #   bank.add_rate("USD", "CAD", 1.24515)  #=> 1.24515
      #   bank.add_rate("CAD", "USD", 0.803115)  #=> 0.803115
      def add_rate(from, to, rate)
        set_rate(from, to, rate)
      end

      # Set the rate for the given currencies. Uses +Mutex+ to synchronize data
      # access.
      #
      # @param [Currency, String, Symbol] from Currency to exchange from.
      # @param [Currency, String, Symbol] to Currency to exchange to.
      # @param [Numeric] rate Rate to use when exchanging currencies.
      # @param [Hash] opts Options hash to set special parameters
      # @option opts [Boolean] :without_mutex disables the usage of a mutex
      #
      # @return [Numeric]
      #
      # @example
      #   @bank = Money::Bank::Currencylayer.new  #=> <Money::Bank::Currencylayer...>
      #   bank.set_rate("USD", "CAD", 1.24515)  #=> 1.24515
      #   bank.set_rate("CAD", "USD", 0.803115)  #=> 0.803115
      def set_rate(from, to, rate)
        if self.class.rates_careful
          set_rate_with_time(from, to, rate)
        else
          super
        end
      end


      # Return the rate hashkey for the given currencies.
      #
      # @param [Currency, String, Symbol] from The currency to exchange from.
      # @param [Currency, String, Symbol] to The currency to exchange to.
      #
      # @return [String]
      #
      # @example
      #   rate_key_for("USD", "CAD") #=> "USD_TO_CAD"
      #   Money::Bank::Currencylayer.rates_careful = true
      #   rate_key_for("USD", "CAD") #=> "USD_TO_CAD_C"
      def rate_key_for(from, to)
        key = "#{Currency.wrap(from).iso_code}_TO_#{Currency.wrap(to).iso_code}"
        key += '_C' if self.class.rates_careful
        key.upcase
      end

      ##
      # Flushes all the rates if they are expired.
      #
      # @return [Boolean]
      def expire_rates
        if expired?
          flush_rates
          self.class.refresh_rates_expiration!
          true
        else
          false
        end
      end

      private

      ##
      # Returns whether the time expired.
      #
      # @return [Boolean]
      def expired?
        self.class.ttl_in_seconds && self.class.rates_expiration <= Time.now
      end

      ##
      # Returns the requested rate.
      #
      # It not flushes all the rates and create rates with created_at time.
      # Check expired for each rate respectively.
      # If it can't get new rate by some reason it returns cached value.
      #
      # @param [String, Symbol, Currency] from Currency to convert from
      # @param [String, Symbol, Currency] to Currency to convert to
      #
      # @return [Float] The requested rate.
      def get_rate_careful(from, to)
        rate_key = rate_key_for(from, to)
        rate_cached = self.store.get_rate(from, to)

        if rate_key.nil? || expired_time?(rate_cached[:created_at])
          set_rate_with_time(from, to, fetch_rate(from, to))
          @rates[rate_key][:rate]
        else
          rate_cached[:rate]
        end
      rescue RequestError => e
        if rate_cached.nil?
          raise e
        else
          rate_cached[:rate]
        end
      end

      ##
      # Returns the requested rate.
      #
      # It also flushes all the rates when and if they are expired.
      #
      # @param [String, Symbol, Currency] from Currency to convert from
      # @param [String, Symbol, Currency] to Currency to convert to
      #
      # @return [Float] The requested rate.
      def get_rate_straight(from, to)
        expire_rates

        self.store.transaction{
          self.store.get_rate(from, to)
        }
      end

      # Registers a conversion rate with created_at
      # and returns it (uses +#set_rate_with_time+).
      #
      # @param [Currency, String, Symbol] from Currency to exchange from.
      # @param [Currency, String, Symbol] to Currency to exchange to.
      # @param [Numeric] rate Rate to use when exchanging currencies.
      #
      # @return [Numeric]
      def add_rate_with_time(from, to, rate)
        set_rate_with_time(from, to, rate)
      end

      # Set the rate and created_at time for the given currencies.
      # Uses +Mutex+ to synchronize data access.
      #
      # @param [Currency, String, Symbol] from Currency to exchange from.
      # @param [Currency, String, Symbol] to Currency to exchange to.
      # @param [Numeric] rate Rate to use when exchanging currencies.
      # @param [Hash] opts Options hash to set special parameters
      # @option opts [Boolean] :without_mutex disables the usage of a mutex
      #
      # @return [Numeric]
      def set_rate_with_time(from, to, rate)
        rate_d = BigDecimal.new(rate.to_s)

        self.store.transaction {
          self.store.add_rate(from, to, { rate: rate_d, created_at: Time.now })
        }

        rate_d
      end

      ##
      # Check if time is expired
      #
      # @param [Time] time Time to check
      #
      # @return [Boolean] Is the time expired.
      def expired_time?(time)
        time + self.class.ttl_in_seconds.to_i < Time.now
      end

      ##
      # Queries for the requested rate and returns it.
      #
      # @param [String, Symbol, Currency] from Currency to convert from
      # @param [String, Symbol, Currency] to Currency to convert to
      #
      # @return [BigDecimal] The requested rate.
      def fetch_rate(from, to)
        from, to = Currency.wrap(from), Currency.wrap(to)
        uri = build_uri(from, to)
        data = perform_request(uri)
        extract_rate(data, from, to)
      end

      ##
      # Performs request on uri or raise exception message with RequestError
      #
      # @param [String] uri Requested uri
      #
      # @return [String]
      def perform_request(uri)
        uri.read
      rescue Exception => e
        raise RequestError, e.message
      end

      ##
      # Build a URI for the given arguments.
      #
      # @param [Currency] from The currency to convert from.
      # @param [Currency] to The currency to convert to.
      #
      # @return [URI::HTTP]
      def build_uri(from, to)
        raise AccessError if access_key.nil? || access_key.empty?
        uri = URI::HTTP.build(
          :host  => SERVICE_HOST,
          :path  => SERVICE_PATH,
          :query => "access_key=#{access_key}&source=#{from}&currencies=#{to}"
        )
      end

      ##
      # Takes the response from jsonrates.com and extract the rate.
      #
      # @param [String] data HTTP-Response of api.
      #
      # @return [BigDecimal]
      def extract_rate(data, from, to)
        request_hash = JSON.parse(data)
        success = request_hash['success']
        raise RequestError, request_hash['error']['info'] unless success
        BigDecimal.new(request_hash['quotes']["#{from}#{to}"].to_s)
      end
    end
  end
end