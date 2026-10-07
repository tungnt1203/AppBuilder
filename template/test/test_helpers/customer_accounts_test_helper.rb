# Customer accounts are off by default (config.x.customer_accounts). Tests of the account screens
# turn them on for themselves: `setup { enable_customer_accounts }`.
module CustomerAccountsTestHelper
  def enable_customer_accounts
    @customer_accounts_were = Rails.configuration.x.customer_accounts unless defined?(@customer_accounts_were)
    Rails.configuration.x.customer_accounts = true
  end

  def after_teardown
    Rails.configuration.x.customer_accounts = @customer_accounts_were if defined?(@customer_accounts_were)
    super
  end
end

ActiveSupport.on_load(:active_support_test_case) { include CustomerAccountsTestHelper }
