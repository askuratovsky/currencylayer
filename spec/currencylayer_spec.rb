require 'spec_helper'

describe "Currencylayer" do
  before :each do
    @bank = Money::Bank::Currencylayer.new
    @bank.access_key = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
  end

  it "should accept a ttl_in_seconds option" do
    Money::Bank::Currencylayer.ttl_in_seconds = 86400
    expect(Money::Bank::Currencylayer.ttl_in_seconds).to eq(86400)
  end

  describe '.get_rate' do
    it 'returns rate' do
      uri = @bank.send(:build_uri, 'USD', 'EUR').to_s
      stub_request(:get, uri).to_return( :status => 200,
        :body => '{"success":true,"terms":"https:\/\/currencylayer.com\/terms","privacy":"https:\/\/currencylayer.com\/privacy","timestamp":1434443053,"source":"USD","quotes":{"USDEUR":0.887701}}')

      @bank.flush_rates
      rate = @bank.get_rate('USD', 'EUR')
      expect(rate).to eq(BigDecimal.new("0.887701"))
    end
    context "in careful mode" do

      it "don't flush rate if get some exception on request" do

        Money::Bank::Currencylayer.rates_careful = true
        Money::Bank::Currencylayer.ttl_in_seconds = 0

        @bank.flush_rates
        @bank.add_rate('USD', 'EUR', 1.011)


        uri = @bank.send(:build_uri, 'USD', 'EUR').to_s

        stub_request(:get, uri).to_return(:status => 200, :body => '{"success":false,"error":{"code":202,"info":"You have provided one or more invalid Currency Codes. [Required format: currencies=EUR,USD,GBP,...]"}}')
        rate = @bank.get_rate('USD', 'EUR')
        expect(rate).to eq(BigDecimal.new("1.011"))

        Money::Bank::Currencylayer.rates_careful = false
      end

    end
  end

  describe ".refresh_rates_expiration!" do
    it "set the .rates_expiration using the TTL and the current time" do
      Money::Bank::Currencylayer.ttl_in_seconds = 86400
      new_time = Time.now
      Timecop.freeze(new_time)
      Money::Bank::Currencylayer.refresh_rates_expiration!
      expect(Money::Bank::Currencylayer.rates_expiration).to eq(new_time + 86400)
    end
  end

  describe ".flush_rates" do
    it "should empty @rates" do
      @bank.add_rate("USD", "CAD", 1.24515)
      @bank.flush_rates
      expect(@bank.rates).to eq({})
    end
  end

  describe 'careful mode' do
    it 'returns cached value if exception raised' do
      @bank.flush_rates
      @bank.add_rate("USD", "CAD", 32.231)
      expect(@bank.get_rate("USD", "CAD")).to eq (BigDecimal.new('32.231'))
    end
  end

  describe ".flush_rate" do
    it "should remove a specific rate from @rates" do
      @bank.flush_rates
      @bank.add_rate('USD', 'EUR', 1.4)
      @bank.add_rate('USD', 'JPY', 0.3)
      @bank.flush_rate('USD', 'EUR')
      expect(@bank.rates).to include('USD_TO_JPY')
      expect(@bank.rates).to_not include('USD_TO_EUR')
    end
  end

  describe ".expire_rates" do
    before do
      Money::Bank::Currencylayer.ttl_in_seconds = 1000
    end

    context "when the ttl has expired" do
      before do
        new_time = Time.now + 1001
        Timecop.freeze(new_time)
      end

      it "should flush all rates" do
        expect(@bank).to receive(:flush_rates)
        @bank.expire_rates
      end

      it "updates the next expiration time" do
        exp_time = Time.now + 1000

        @bank.expire_rates
        expect(Money::Bank::Currencylayer.rates_expiration).to eq(exp_time)
      end
    end

    context "when the ttl has not expired" do
      it "not should flush all rates" do
        expect(@bank).to_not receive(:flush_rates)
        @bank.expire_rates
      end
    end
  end
end