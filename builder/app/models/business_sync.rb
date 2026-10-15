# Applies an owner's business settings (BusinessSetting: Stripe, Printify, ad pixels) to one of
# their apps, where it runs: its preview, and its published copy on ONCE when it has one. The
# app's shop core does the work (`bin/rails shop:business_settings`, BusinessSettings there);
# the settings go in the BUSINESS_SETTINGS variable (preview) or on stdin (ONCE), never in a
# command's arguments. What each copy answered is kept on the project (business_sync_result).
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
    result = { "preview" => parse(*@project.sandbox.capture("bin/rails", "shop:business_settings", env: { "BUSINESS_SETTINGS" => json })) }
    result["live"] = parse(*live(json)) if @project.deployments.live.exists?
    @project.update!(business_synced_at: Time.current, business_sync_result: result)
    result
  end

  private
    # The app's own setting, when it sells nothing (config.x.shop = false).
    def shop_off?
      @project.path.join("config/application.rb").read.match?(/^\s*config\.x\.shop\s*=\s*false/)
    end

    def live(json)
      script = 'BUSINESS_SETTINGS="$(cat)" exec bin/rails shop:business_settings'
      ProjectShell.new(@project.path).capture(Rails.configuration.x.once_bin, "exec", @project.publish_host, "sh", "-c", script, stdin: json)
    end

    def parse(output, succeeded)
      line = output.to_s.lines.reverse.find { |each| each.start_with?(MARKER) }
      return JSON.parse(line.delete_prefix(MARKER).strip) if succeeded && line

      reason = output.to_s.include?("Don't know how to build task") ? "Update the app first (its shop core is older)" : output.to_s.strip.last(300)
      { "errors" => [ reason.presence || "It didn't answer" ] }
    rescue JSON::ParserError
      { "errors" => [ "Its answer couldn't be read" ] }
    end
end
