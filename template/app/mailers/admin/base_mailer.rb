# Emails to the owner and staff, in /admin's language (config.x.admin_locale).
class Admin::BaseMailer < ApplicationMailer
  around_action :use_admin_locale

  private
    def use_admin_locale(&)
      I18n.with_locale(Rails.configuration.x.admin_locale || I18n.default_locale, &)
    end
end
