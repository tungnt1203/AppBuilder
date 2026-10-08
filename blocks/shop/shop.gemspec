require_relative "lib/shop/version"

Gem::Specification.new do |spec|
  spec.name = "shop"
  spec.version = Shop::VERSION
  spec.summary = "The shop core of apps made with AppBuilder: catalog, cart, checkout, orders, Stripe payments"
  spec.authors = [ "AppBuilder" ]
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"
  spec.files = Dir["{app,config,db,lib}/**/*", "LICENSE", "README.md"]

  spec.add_dependency "rails", ">= 8.1"
  spec.add_dependency "stripe", "~> 20.0"
end
