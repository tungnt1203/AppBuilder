Rails.application.routes.draw do
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
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
