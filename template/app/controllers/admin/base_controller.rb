class Admin::BaseController < ApplicationController
  before_action :require_administrator

  private
    def require_administrator
      redirect_to root_path, alert: "Only admins can do that." unless Current.user.administrator?
    end
end
