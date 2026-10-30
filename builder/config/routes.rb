Rails.application.routes.draw do
  resource :session
  resources :looks, only: :show
  resource :registration, only: %i[ new create ]
  resource :tour, only: :create
  get "business", to: redirect("/admin/settings")
  resources :passwords, param: :token
  resources :invitations, only: %i[ show update ], param: :token
  root "projects#index"
  get "s/:token", to: "shares#show", as: :shared_preview

  resources :projects, only: %i[ index create show update destroy ] do
    resources :messages, only: :create, module: :projects
    resources :chats, only: %i[ create update destroy ], module: :projects do
      post :open, on: :member
      post :fork, on: :member
    end
    resources :deployments, only: :create, module: :projects
    resources :restorations, only: :create, module: :projects
    resource :update, only: :create, module: :projects
    resource :build, only: :create, module: :projects
    resource :stop, only: :create, module: :projects
    resource :worker_check, only: :show, module: :projects
    resource :preview, only: %i[ show create ], module: :projects
    resource :thumbnail, only: :show, module: :projects
    resource :duplicate, only: :create, module: :projects
    resource :code, only: :show, module: :projects
    resource :design, only: %i[ show update ], module: :projects do
      post :theme
      get "looks/:slug", action: :look, as: :look
      post "looks/:slug/try", action: :try_look, as: :try_look
      post :keep_look
      post :revert_look
      patch :content
      get :photos
      post :photo
    end
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
      resources :artwork, only: :destroy, module: :products
      resource :print_file, only: :show, module: :products
      resource :print_area, only: :create, module: :products
      resource :duplicate, only: :create, module: :products
    end
    resource :demo_products, only: %i[ create destroy ]
    resources :clipart_sets, path: "clipart" do
      resources :pictures, only: %i[ create update destroy ], module: :clipart_sets
    end
    resources :collections
    resources :discounts, except: :show
    resources :product_reviews, only: %i[ index update ], path: "reviews"
    resources :promotions, only: %i[ index new create ] do
      resource :cancellation, only: :create, module: :promotions
    end
    resources :customers, only: %i[ index show ]
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
        resource :printify_order, only: :create
      end
    end
    resource :printify_connection, only: %i[ show create update destroy ], path: "settings/printify"
    resources :printify_imports, only: %i[ index create ], path: "printify/products"
    resource :stripe_connection, only: %i[ create update destroy ]
    resource :settings, only: %i[ edit update ]
    resource :policies, only: %i[ edit update ], path: "settings/policies"
    resource :theme_setting, only: %i[ edit update ], path: "settings/theme"
    resource :custom_fields, only: %i[ edit update ], path: "settings/fields"
    resources :pages, except: :show
    resources :menus, except: :show
    resources :platform_requests, only: %i[ index update ], path: "requests"
    resources :forms, except: :show do
      resources :submissions, only: :show, module: :forms
    end
    resources :api_keys, only: %i[ index create destroy ], path: "settings/keys"
    resources :memberships, only: %i[ index new create update destroy ], path: "people"
  end

  # Stripe and Printify call each shop's address here (Webhooks::BaseController).
  scope "webhooks", module: :webhooks, as: :webhooks do
    post "stripe/:shop_uid", to: "stripe#create", as: :stripe
    post "printify/:shop_uid", to: "printify#create", as: :printify
  end

  # The Storefront API, for the shops' storefronts (StorefrontApi::V1::BaseController).
  scope "v1", module: "storefront_api/v1", as: "storefront_api", defaults: { format: :json } do
    resource :shop, only: :show
    resources :products, only: %i[ index show ] do
      resources :reviews, only: :index
    end
    resources :collections, only: %i[ index show ]
    resources :policies, only: :show
    resources :pages, only: :show
    resources :menus, only: :show
    resources :forms, only: [], param: :key do
      resources :submissions, only: :create, module: :forms
    end
    resources :zip_codes, only: :show
    resources :uploads, only: :create
    resources :carts, only: %i[ create show ] do
      scope module: :carts do
        resources :items, only: %i[ create update destroy ]
        resource :discount, only: %i[ create destroy ]
      end
    end
    resources :checkouts, only: :create do
      post :quote, on: :collection
    end
    resources :order_lookups, only: %i[ create show ]
    resources :orders, only: :show do
      scope module: :orders do
        resources :reviews, only: :create
        resource :payment, only: :create
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
