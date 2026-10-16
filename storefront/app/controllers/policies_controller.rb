# The shop's refund, shipping, privacy and terms pages, written by the owner in the admin.
class PoliciesController < ApplicationController
  def show
    @policy = storefront.policy(params[:id])
    raise StorefrontKit::NotFound.new("No policy", status: 404) if @policy.body.blank?
  end
end
