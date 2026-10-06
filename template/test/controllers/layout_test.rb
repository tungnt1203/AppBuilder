require "test_helper"

class LayoutTest < ActionDispatch::IntegrationTest
  test "visitors on public pages see a sign in link instead of the account menu" do
    with_routing do |routes|
      routes.draw do
        get "public" => "public_test#show"
        resource :session
        resources :passwords, param: :token
        resource :first_run, only: %i[ new create ]
        namespace(:admin) { resources :users }
        root "home#show"
      end

      User.delete_all
      get "/public"

      assert_response :success
      assert_select "a[href='/session/new']"
      assert_select "aside#app-nav"
      assert_select "main#main"
      assert_select "button[aria-controls=?]", "app-nav"
    end
  end
end

class PublicTestController < ApplicationController
  allow_unauthenticated_access

  def show
    render html: "", layout: "application"
  end
end
