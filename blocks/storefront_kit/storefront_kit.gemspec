require_relative "lib/storefront_kit/version"

Gem::Specification.new do |spec|
  spec.name = "storefront_kit"
  spec.version = StorefrontKit::VERSION
  spec.summary = "What a shop's storefront uses to talk to the Platform's Storefront API: a client, typed records, a cache and view helpers"
  spec.authors = [ "AppBuilder" ]
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"
  spec.files = Dir["{app,lib}/**/*", "LICENSE", "README.md"]

  spec.add_dependency "rails", ">= 8.1"
end
