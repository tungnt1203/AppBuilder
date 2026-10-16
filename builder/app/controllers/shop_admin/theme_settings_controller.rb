# The values of the storefront's theme (Settings → Theme). The fields themselves come from the
# storefront, applied with ThemeSetting.apply_schema! when it is published.
class ShopAdmin::ThemeSettingsController < ShopAdmin::BaseController
  before_action :require_administrator

  def edit
    @theme_setting = ThemeSetting.current
  end

  def update
    @theme_setting = ThemeSetting.current
    if @theme_setting.schema.blank?
      redirect_to edit_shop_admin_theme_setting_path, alert: t(".not_declared")
    elsif @theme_setting.update_values(theme_values, uploads: theme_images, removals: theme_removals)
      redirect_to edit_shop_admin_theme_setting_path, notice: t(".notice")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def theme_values
      params.fetch(:theme_setting, ActionController::Parameters.new).permit(values: {})[:values]&.to_h || {}
    end

    def theme_images
      value = params.dig(:theme_setting, :images)
      case value
      when ActionController::Parameters then value.to_unsafe_h
      when Hash then value
      else {}
      end
    end

    def theme_removals
      Array(params.dig(:theme_setting, :remove_images))
    end
end
