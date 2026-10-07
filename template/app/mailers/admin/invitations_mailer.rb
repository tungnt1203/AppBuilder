class Admin::InvitationsMailer < Admin::BaseMailer
  def invite(user)
    @user = user
    @invitation_url = admin_invitation_url(user.generate_token_for(:invitation))
    mail subject: t(".subject", app: Rails.configuration.x.app_name), to: user.email_address
  end
end
