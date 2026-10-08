# How booking works: the step between times offered, the notice, how far ahead, until when
# customers can cancel. Admins only.
class Admin::BookingSettingsController < Admin::BaseController
  before_action :require_booking
  before_action :require_administrator

  def edit
    @booking_setting = BookingSetting.current
  end

  def update
    @booking_setting = BookingSetting.current

    if @booking_setting.update(params.expect(booking_setting: %i[ slot_minutes min_notice_minutes max_days_ahead cancel_notice_hours ]))
      redirect_to edit_admin_booking_settings_path, notice: t(".notice")
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
