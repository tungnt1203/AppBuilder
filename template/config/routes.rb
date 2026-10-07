Rails.application.routes.draw do
  # The customers' site: public pages, and customers' own accounts.
  root "home#show"

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
