Rails.application.routes.draw do
  # The customers' site: the shop, and customers' own accounts (when config.x.customer_accounts).
  root "home#show"

  resources :products, only: %i[ index show ]
  resources :collections, only: :show
  resource :cart, only: :show
  resources :cart_items, only: %i[ create update destroy ]
  resource :checkout, only: %i[ new create ]
  resources :orders, only: :show do
    resource :payment, only: :create, module: :orders
  end
  resources :policies, only: :show
  resource :contact, only: :show
  post "stripe/webhook" => "stripe_webhooks#create", as: :stripe_webhook

  resource :registration, only: %i[ new create ]
  resource :session, only: %i[ new create destroy ]
  resources :passwords, only: %i[ new create edit update ], param: :token
  resource :account, only: %i[ show edit update ]

  # Where the owner and staff run the app, with their own accounts and sign in.
  namespace :admin do
    root "dashboards#show"

    resource :session, only: %i[ new create destroy ]
    resources :passwords, only: %i[ new create edit update ], param: :token
    resource :first_run, only: %i[ new create ]
    resources :invitations, only: %i[ show update ], param: :token
    resources :products do
      resources :images, only: :destroy, module: :products
    end
    resources :collections
    resources :orders, only: %i[ index show update ] do
      scope module: :orders do
        resource :payment, only: :create
        resource :production, only: :create
        resource :shipment, only: :create
        resource :delivery, only: :create
        resource :cancellation, only: :create
        resource :refund, only: :create
      end
    end
    resource :settings, only: %i[ edit update ]
    resource :stripe_connection, only: %i[ create update destroy ]
    resource :policies, only: %i[ edit update ], path: "settings/policies"
    resources :users
  end

  # Every page block in this app's theme, to pick from (design skill). Development only.
  get "_blocks" => "blocks#index", as: :blocks if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # ONCE uses it to decide whether a new version is healthy before switching traffic to it.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
