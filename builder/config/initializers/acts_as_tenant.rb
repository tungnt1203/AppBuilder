# A shop's data is only ever read inside its shop: querying a shop-scoped model without a current
# shop raises, instead of quietly returning every shop's rows. Code that means to look across
# shops (finding an API key's shop, the platform's own jobs) says so with
# ActsAsTenant.without_tenant.
ActsAsTenant.configure do |config|
  config.require_tenant = true
end
