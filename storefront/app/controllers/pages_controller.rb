# The shop's own pages (about, FAQ…), written in the admin: text and questions.
class PagesController < ApplicationController
  def show
    @page = storefront.page(params[:id])
  end
end
