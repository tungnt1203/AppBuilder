# An account made for someone added to a shop: the link to choose their password.
class InvitationsMailer < ApplicationMailer
  def invite(user, shop)
    @user, @shop = user, shop
    mail subject: "You've been added to #{shop.name}", to: user.email_address
  end
end
