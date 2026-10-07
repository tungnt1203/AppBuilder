# Preview all emails at http://localhost:3000/rails/mailers/admin/invitations_mailer
class Admin::InvitationsMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/admin/invitations_mailer/invite
  def invite
    Admin::InvitationsMailer.invite(User.take)
  end
end
