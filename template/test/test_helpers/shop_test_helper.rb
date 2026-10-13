# Tests start with the shop on (config.x.shop), whatever the app sets, so the shop's own tests
# keep passing in an app that turned it off. Tests of the app without it call `disable_shop` in
# `setup`. Routes check the switch on each request.
module ShopTestHelper
  def before_setup
    @shop_was = Rails.configuration.x.shop
    Rails.configuration.x.shop = true
    super
  end

  def disable_shop
    Rails.configuration.x.shop = false
  end

  def after_teardown
    Rails.configuration.x.shop = @shop_was
    super
  end
end

ActiveSupport.on_load(:active_support_test_case) { include ShopTestHelper }
