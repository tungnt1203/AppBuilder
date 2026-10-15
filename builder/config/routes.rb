Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[ new create ]
  resource :tour, only: :create
  get "business", to: redirect("/admin/settings")
  resources :passwords, param: :token
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
    resource :orders_refresh, only: :create
    resources :users, only: %i[ index update destroy ]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
