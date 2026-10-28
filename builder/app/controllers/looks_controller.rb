# The picture of a Hallmark look (HallmarkLook), for the studio's home.
class LooksController < ApplicationController
  def show
    picture = HallmarkLook.find(params[:id])&.picture or raise ActiveRecord::RecordNotFound
    expires_in 1.week, public: true
    send_file picture, type: "image/jpeg", disposition: "inline"
  end
end
