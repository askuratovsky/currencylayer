# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "currencylayer"
  spec.version       = '0.0.2'
  spec.authors       = ["Andrey Skuratovsky"]
  spec.email         = ["skuratowsky@gmail.com"]
  spec.summary       = "Access to the currencylayer.com online exchange rates"
  spec.description   = "This gem extends Money::Bank::VariableExchange with Money::Bank::Currencylayer and gives you access to the current exchange rates on currencylayer.com."
  spec.homepage      = "http://github.com/askuratovsky/#{spec.name}"
  spec.license       = "MIT"

  spec.files         =  Dir.glob("{lib,spec}/**/*")
  spec.require_paths = ["lib"]

  spec.add_dependency "money", "~> 6"

  spec.add_development_dependency "rspec", ">= 3.0.0"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
