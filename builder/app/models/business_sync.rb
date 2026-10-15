# Applies an owner's business settings (BusinessSetting: Stripe, Printify, ad pixels) to one of
# their apps, where it runs: its preview, and its published copy on ONCE when it has one. The
# app's shop core does the work (`bin/rails shop:business_settings`, BusinessSettings there);
# the settings go in a variable (preview) or on stdin (ONCE), never in a command's arguments
# (AppTask). What each copy answered is kept on the project (business_sync_result).
class BusinessSync
  MARKER = "BUSINESS_SETTINGS_RESULT"

  def initialize(project, settings = project.owner&.business_setting)
    @project, @settings = project, settings
  end

  def applicable?
    @settings&.configured? && (@project.ready? || @project.working?) && @project.path.join("config/application.rb").exist? && !shop_off?
  end

  def call
    return unless applicable?

    json = @settings.payload.to_json
    task = AppTask.new(@project)
    result = { "preview" => task.run("shop:business_settings", marker: MARKER, input: json) }
    result["live"] = task.run("shop:business_settings", marker: MARKER, copy: :live, input: json) if @project.deployments.live.exists?
    @project.update!(business_synced_at: Time.current, business_sync_result: result)
    result
  end

  # The app's own setting, when it sells nothing (config.x.shop = false).
  def self.sells?(project)
    application = project.path.join("config/application.rb")
    application.exist? && !application.read.match?(/^\s*config\.x\.shop\s*=\s*false/)
  end

  private
    def shop_off?
      !self.class.sells?(@project)
    end
end
