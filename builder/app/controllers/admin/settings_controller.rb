# The owner's admin over all their shops (/admin), its settings: Stripe, Printify and their ad
# pixels, set once (BusinessSetting) and applied to every shop they own or administer
# (BusinessSync), where each can still be changed in that shop's own settings.
class Admin::SettingsController < Admin::BaseController
  SECRETS = %w[ stripe_secret_key printify_token meta_access_token ].freeze

  def show
    @setting = Current.user.business_setting || Current.user.build_business_setting
    load_page
  end

  def update
    @setting = Current.user.business_setting || Current.user.build_business_setting
    @setting.assign_attributes(setting_params)
    pick_printify_shop

    if @setting.errors.none? && @setting.save
      shops.each { |shop| BusinessSyncJob.perform_later(shop, Current.user) }
      redirect_to admin_settings_path, notice: "Saved. Your shops are getting the new settings."
    else
      load_page
      render :show, status: :unprocessable_entity
    end
  end

  private
    # Secrets aren't shown again: a blank field keeps what's saved, "Disconnect" clears it.
    def setting_params
      permitted = params.expect(business_setting: [ *BusinessSetting::KEYS, *SECRETS.map { |key| "clear_#{key}" } ])
      attributes = permitted.except(*SECRETS, *SECRETS.map { |key| "clear_#{key}" }).to_h
      SECRETS.each do |key|
        if permitted["clear_#{key}"] == "1"
          attributes[key] = nil
          attributes.merge!("printify_shop_id" => nil, "printify_shop_title" => nil) if key == "printify_token"
        elsif permitted[key].present?
          attributes[key] = permitted[key]
        end
      end
      attributes
    end

    # The account's shop: picked by itself when there's one, else the owner picks it.
    def pick_printify_shop
      return @setting.assign_attributes(printify_shop_id: nil, printify_shop_title: nil) if @setting.printify_token.blank?
      return unless @setting.printify_token_changed? || @setting.printify_shop_id_changed? || @setting.printify_shop_id.blank?

      @printify_shops = PrintifyAccount.shops(@setting.printify_token)
      @setting.printify_shop_id = @printify_shops.first["id"].to_s if @printify_shops.one?
      shop = @printify_shops.find { |each| each["id"].to_s == @setting.printify_shop_id.to_s }
      @setting.printify_shop_title = shop&.dig("title")
      @setting.printify_shop_id = nil unless shop
    rescue PrintifyAccount::Error => error
      @setting.errors.add(:printify_token, error.message)
    end

    def load_page
      @shops = shops
      @printify_shops ||= (PrintifyAccount.shops(@setting.printify_token) rescue []) if @setting.printify_token.present? && @setting.printify_shop_id.blank?
    end

    # The shops whose settings are theirs to change.
    def shops
      Current.user.shops.where(shop_memberships: { role: %w[ owner admin ] }).order(:name)
    end
end
