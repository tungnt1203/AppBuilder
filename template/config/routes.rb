Rails.application.routes.draw do
  root "home#show"

  resource :session
  resources :passwords, param: :token
  resource :first_run, only: %i[ new create ]
  resources :invitations, only: %i[ show update ], param: :token

  namespace :admin do
    resources :users
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # ONCE uses it to decide whether a new version is healthy before switching traffic to it.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
