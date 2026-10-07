# Preview all emails at http://localhost:3000/rails/mailers/admin/passwords_mailer
class Admin::PasswordsMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/admin/passwords_mailer/reset
  def reset
    Admin::PasswordsMailer.reset(User.take)
  end
end
