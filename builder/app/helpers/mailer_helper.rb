# Pieces of emails: styled inline, since email clients drop styles from anywhere else.
module MailerHelper
  # The email's main link, as a button.
  def email_button(text, url)
    link_to text, url, style: "display: inline-block; margin-top: 8px; padding: 12px 22px; border-radius: 8px; background: #111827; " \
      "color: #ffffff; font-size: 15px; font-weight: 600; text-decoration: none;"
  end
end
