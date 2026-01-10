require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "ui/home#index"

  # User-facing HTML UI (no /ui prefix)
  scope module: :ui do
    resources :orders, only: %i[index new create show]
    get "login" => "sessions#new", as: :login
    post "login" => "sessions#create"
    delete "logout" => "sessions#destroy", as: :logout
    get "signup" => "registrations#new", as: :signup
    post "signup" => "registrations#create"
  end

  namespace :admin do
    root "dashboard#index"

    Sidekiq::Web.use Rack::Auth::Basic do |user, pass|
      expected_user = ENV.fetch("ADMIN_USER", "admin")
      expected_pass = ENV.fetch("ADMIN_PASSWORD", "admin")
      ActiveSupport::SecurityUtils.secure_compare(user.to_s, expected_user) &
        ActiveSupport::SecurityUtils.secure_compare(pass.to_s, expected_pass)
    end
    mount Sidekiq::Web => "/sidekiq"

    resources :inventory, only: %i[index destroy] do
      collection do
        post :create_sku
      end
    end
    resources :skus, only: %i[index destroy]
    resources :warehouses
    get "logout" => "sessions#destroy"
  end

  # JSON API (moved under /api to avoid route collisions with HTML UI)
  scope "/api", as: :api, defaults: { format: :json } do
    resources :skus, only: %i[index create]
    resources :warehouses, only: %i[index create]

    get "inventory" => "inventory#index"
    post "inventory/adjust" => "inventory#adjust"

    resources :orders, only: %i[create show] do
      member do
        post :cancel
        post :fulfill
      end
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
