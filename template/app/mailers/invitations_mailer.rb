class InvitationsMailer < ApplicationMailer
  def invite(user)
    @user = user
    @invitation_url = invitation_url(user.generate_token_for(:invitation))
    mail subject: t(".subject", app: Rails.configuration.x.app_name), to: user.email_address
  end
end
