# The shop's refund, shipping, privacy and terms pages, written by the owner in /admin.
class PoliciesController < ApplicationController
  def show
    @store = Store.current
    @id = params[:id]
    raise ActiveRecord::RecordNotFound unless Store::POLICIES.key?(@id) && @store.policy(@id)
  end
end
