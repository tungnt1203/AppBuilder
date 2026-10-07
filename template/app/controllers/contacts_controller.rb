# How buyers reach the shop: email, phone and address from /admin's policies screen.
class ContactsController < ApplicationController
  def show
    @store = Store.current
  end
end
