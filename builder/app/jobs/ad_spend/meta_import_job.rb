# Every few hours, in every shop with its Meta ad account given (Store#meta_ad_spend?): the
# account's spend for each of the last week's days, as facebook in Ad spend (a day's spend keeps
# changing for a while). It replaces what was entered by hand for those days. An account in another
# currency than the shop's is left for the owner to enter; a refusal is shown in the settings.
class AdSpend::MetaImportJob < ApplicationJob
  DAYS = 7
  SOURCE = "facebook"

  def perform
    Shop.each_in_turn do
      store = Store.current
      next unless store.meta_ad_spend?

      import(store, ActsAsTenant.current_tenant)
    end
  end

  private
    def import(store, shop)
      till = Time.current.in_time_zone(shop.time_zone).to_date
      spend, currency = store.meta_ads.daily_spend(store.meta_ad_account_id, since: till - (DAYS - 1), till:)
      if currency.present? && currency != store.currency
        return store.update_columns(meta_ad_spend_error: "Your Meta ad account is in #{currency} and the shop in #{store.currency}, so its spend isn't brought in: enter it under Ad spend in #{store.currency}.")
      end

      spend.each { |date, amount| AdSpend.record(date:, source: SOURCE, amount:) }
      store.update_columns(meta_ad_spend_error: nil, meta_ad_spend_synced_at: Time.current)
    rescue MetaGateway::Refused => refused
      store.update_columns(meta_ad_spend_error: refused.message)
    end
end
