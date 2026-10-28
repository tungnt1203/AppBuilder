Rails.application.routes.draw do
  # The shop: catalog, the owner's pages, cart, checkout, the buyer's order page, the ad catalogs' feed.
  root "home#show"

  resources :products, only: %i[ index show ]
  resources :collections, only: :show
  resources :pages, only: :show
  resource :cart, only: :show do
    resource :discount, only: %i[ create destroy ], module: :carts
  end
  resources :cart_items, only: %i[ create update destroy ]
  resources :uploads, only: :create
  resource :checkout, only: %i[ new create ] do
    get :shipping
  end
  resources :zip_codes, only: :show
  # "Find my order": the buyer's orders by email, through a link the shop emails them.
  get "orders/find", to: "order_lookups#new", as: :new_order_lookup
  post "orders/find", to: "order_lookups#create", as: :order_lookups
  get "orders/find/sent", to: "order_lookups#sent", as: :sent_order_lookup
  get "orders/find/:token", to: "order_lookups#show", as: :order_lookup
  resources :orders, only: :show do
    resource :payment, only: :show, module: :orders
    resource :review, only: %i[ new create ], module: :orders
  end
  get "feeds/products", to: "feeds#products", defaults: { format: :xml }, as: :products_feed
  resources :policies, only: :show
  resource :contact, only: :show
  post "forms/:form_key", to: "form_submissions#create", as: :form_submissions

  # Every page block in this app's theme, to pick from (design skill). Development only.
  get "_blocks" => "blocks#index", as: :blocks if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # ONCE uses it to decide whether a new version is healthy before switching traffic to it.
  get "up" => "rails/health#show", as: :rails_health_check

  # Last: any other address is the shop's own "not found" page (Rails' own paths excepted).
  match "*path", to: "errors#not_found", via: :all, constraints: ->(request) { !request.path.start_with?("/rails/") }
end
