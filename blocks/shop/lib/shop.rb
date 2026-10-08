require "stripe"
require "shop/version"
require "shop/engine"

module Shop
  # Core models end with `Shop.extend_model(self)`. An app adds to one of them (associations,
  # validations, scopes, methods of its own) in app/models/<model>/extension.rb:
  #
  #   module Product::Extension
  #     extend ActiveSupport::Concern
  #
  #     included do
  #       has_many :reviews, dependent: :destroy
  #     end
  #   end
  #
  # It's included after the core's own code, so it adds to the model; it doesn't replace what the
  # core does (prices, order statuses, payments).
  def self.extend_model(model)
    model.include(model::Extension) if model.const_defined?(:Extension, false)
  end
end
