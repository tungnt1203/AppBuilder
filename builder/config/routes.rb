Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[ new create ]
  resource :tour, only: :create
  resources :passwords, param: :token
  root "projects#index"

  resources :projects, only: %i[ index create show update destroy ] do
    resources :messages, only: :create, module: :projects
    resources :deployments, only: :create, module: :projects
    resources :restorations, only: :create, module: :projects
    resource :build, only: :create, module: :projects
    resource :stop, only: :create, module: :projects
    resource :preview, only: :create, module: :projects
    resource :thumbnail, only: :show, module: :projects
    resource :duplicate, only: :create, module: :projects
    resource :code, only: :show, module: :projects
    resource :address, only: :update, module: :projects
    get "messages/:message_id/attachments/:name", to: "projects/attachments#show", as: :attachment, constraints: { name: %r{[^/]+} }
  end

  namespace :admin do
    resources :users, only: %i[ index update destroy ]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
