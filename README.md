# Currencylayer

This gem extends Money::Bank::VariableExchange of gem [money](https://github.com/RubyMoney/money) and gives you access to the current exchange rates using [currencylayer.com](https://currencylayer.com/)

## Features

- supports 168 currencies
- precision of rates up to 6 digits after point
- uses fast and reliable json api
- average response time < 20ms
- supports caching currency rates

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'currencylayer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install currencylayer

## Usage

First, you should to register account on [currencylayer.com](https://currencylayer.com/) and get your personal access_key.

```ruby
require 'money'
require 'money/bank/currencylayer'

# (optional)
# set the seconds after than the current rates are automatically expired
# by default, they never expire
Money::Bank::Currencylayer.ttl_in_seconds = 7200 # 2 hours ttl

# set careful mode - each rate stores with created_at time to cache and will be flushed
# only if their time is out. If you get exception while request new rate, bank will
# return cached value if present
# by default false
Money::Bank::Currencylayer.rates_careful = true

# create new bank instance
bank = Money::Bank::Currencylayer.new

# create new bank instance with block specifying rounding of exchange result
bank = Money::Bank::Currencylayer.new {|n| n.round(4)} # round result to 4 digits after point

# specify your access_key from currencylayer.com
bank.access_key = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

# set default bank to instance
Money.default_bank = bank
```

Also you can setup Currencylayer as default_bank for [money-rails](https://github.com/RubyMoney/money-rails) gem in config/initializers/money.rb

```ruby
require 'money/bank/currencylayer'
MoneyRails.configure do |config|

  bank = Money::Bank::Currencylayer.new
  bank.access_key = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
  config.default_bank = bank

end
```

An `AccessError` will be thrown if access_key was not specified.

An `RequestError` will be thrown if currencylayer.com api returns error on api request.


## Refs

Created using `VariableExchange` implementation and using `google_currency` basics.

- https://github.com/RubyMoney/money
- https://github.com/RubyMoney/google_currency

More implementations:

- https://github.com/RubyMoney/eu_central_bank
- https://github.com/matiaskorhonen/nordea
- https://github.com/slbug/nbrb_currency
- https://github.com/spk/money-open-exchange-rates
- https://github.com/atwam/money-historical-bank
- https://github.com/rmustafin/russian_central_bank

## Contributing

1. Fork it ( https://github.com/[my-github-username]/currencylayer/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
