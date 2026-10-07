class Admin::PasswordsMailer < Admin::BaseMailer
  def reset(user)
    @user = user
    mail subject: t(".subject"), to: user.email_address
  end
end
