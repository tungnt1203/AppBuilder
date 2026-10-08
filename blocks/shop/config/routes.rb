# The agent API, drawn into the app's routes by Shop::Engine (see lib/shop/engine.rb).
Rails.application.routes.draw do
  scope "agent/v1", module: "agent", as: "agent", defaults: { format: :json } do
    scope "storefront", module: "storefront", as: "storefront" do
      resources :products, only: %i[ index show ]
      resource :cart, only: :show do
        get :handoff
      end
      resources :cart_items, only: %i[ create update destroy ], path: "cart/items"
      resources :orders, only: %i[ index show ]
      get "policies" => "infos#policies"
      get "fulfillment" => "infos#fulfillment"
      get "preferences" => "infos#preferences"
    end

    scope "merchant", module: "merchant", as: "merchant" do
      get "context" => "reports#context"
      get "snapshot" => "reports#snapshot"
      get "metrics" => "reports#metrics"
      get "inventory_alerts" => "reports#inventory_alerts"
      get "order_issues" => "reports#order_issues"
      get "campaigns" => "reports#campaigns"
      resources :listings, only: %i[ index show ] do
        get :pricing, on: :member
      end
      resources :changes, only: %i[ index create ] do
        post :apply, on: :member
        post :discard, on: :member
      end
    end
  end

  get "agent/cart/:token" => "agent/cart_claims#show", as: :agent_cart_claim
end
