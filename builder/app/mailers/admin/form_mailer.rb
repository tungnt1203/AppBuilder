# Tells the shop's owners and admins about a form message.
class Admin::FormMailer < ApplicationMailer
  def submission(submission)
    @submission = submission
    recipients = submission.shop.memberships.where(role: %w[ owner admin ]).joins(:user).pluck("users.email_address")
    return if recipients.empty?

    mail to: recipients, subject: t(".subject", title: submission.form.title)
  end
end
