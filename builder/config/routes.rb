Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[ new create ]
  resource :tour, only: :create
  get "business", to: redirect("/admin/settings")
  resources :passwords, param: :token
  resources :invitations, only: %i[ show update ], param: :token
  root "projects#index"
  get "s/:token", to: "shares#show", as: :shared_preview

  resources :projects, only: %i[ index create show update destroy ] do
    resources :messages, only: :create, module: :projects
    resources :deployments, only: :create, module: :projects
    resources :restorations, only: :create, module: :projects
    resource :update, only: :create, module: :projects
    resource :build, only: :create, module: :projects
    resource :stop, only: :create, module: :projects
    resource :preview, only: %i[ show create ], module: :projects
    resource :thumbnail, only: :show, module: :projects
    resource :duplicate, only: :create, module: :projects
    resource :code, only: :show, module: :projects
    resource :address, only: :update, module: :projects
    resource :share, only: %i[ create destroy ], module: :projects
    resource :instructions, only: :update, module: :projects
    resource :download, only: :show, module: :projects
    get "messages/:message_id/attachments/:name", to: "projects/attachments#show", as: :attachment, constraints: { name: %r{[^/]+} }
  end

  # The owner's admin over all their shops; accounts (users) are for administrators only.
  namespace :admin do
    root "dashboards#show"
    resource :settings, only: %i[ show update ]
    resources :products, only: %i[ index create ]
    resources :users, only: %i[ index update destroy ]
    resources :shops, only: %i[ index new create ]
  end

  # One shop's admin, for its members (ShopAdmin::BaseController).
  scope "admin/shops/:shop_id", module: :shop_admin, as: :shop_admin do
    root "dashboards#show"

    resources :products do
      resources :images, only: :destroy, module: :products
    end
    resource :demo_products, only: %i[ create destroy ]
    resources :collections
    resources :discounts, except: :show
    resources :product_reviews, only: %i[ index update ], path: "reviews"
    resources :promotions, only: %i[ index new create ] do
      resource :cancellation, only: :create, module: :promotions
    end
    resources :orders, only: %i[ index show update ] do
      scope module: :orders do
        resource :payment, only: :create
        resource :production, only: :create
        resource :shipment, only: :create
        resource :delivery, only: :create
        resource :cancellation, only: :create
        resource :refund, only: :create
        resource :restock, only: :create
        resource :fulfillment, only: :create
      end
    end
    resource :printify_connection, only: %i[ show create update destroy ], path: "settings/printify"
    resources :printify_imports, only: %i[ index create ], path: "printify/products"
    resource :stripe_connection, only: %i[ create update destroy ]
    resource :settings, only: %i[ edit update ]
    resource :policies, only: %i[ edit update ], path: "settings/policies"
    resources :memberships, only: %i[ index new create update destroy ], path: "people"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
