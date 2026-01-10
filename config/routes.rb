require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "web/home#index"

  # User-facing HTML (no /web prefix)
  scope module: :web do
    resources :orders, only: %i[index new create show]
    post "orders/:id/cancel" => "orders#cancel", as: :cancel_order
    get "orders/:order_id/pay" => "payments#new", as: :new_payment
    post "orders/:order_id/pay" => "payments#create", as: :payments
    post "orders/:order_id/pay_wallet" => "payments#wallet", as: :wallet_payments
    get "orders/:order_id/checkout" => "gateway#show", as: :gateway_checkout
    post "orders/:order_id/checkout" => "gateway#pay", as: :gateway_pay
    get "orders/:order_id/payment_callback" => "payments#callback", as: :payment_callback
    get "login" => "sessions#new", as: :login
    post "login" => "sessions#create"
    delete "logout" => "sessions#destroy", as: :logout
    get "signup" => "registrations#new", as: :signup
    post "signup" => "registrations#create"
    get "wallet" => "wallets#show", as: :wallet
    post "wallet/recharge" => "wallets#recharge", as: :wallet_recharge
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
    resources :skus, only: %i[index update destroy]
    # Explicitly define new/edit routes (in addition to resources) to avoid any
    # ambiguity with :id matching in some environments.
    get "warehouses/new" => "warehouses#new", as: :new_warehouse
    get "warehouses/:id/edit" => "warehouses#edit", as: :edit_warehouse
    resources :warehouses, except: %i[show]
    get "wallets" => "wallets#index"
    post "wallets/credit" => "wallets#credit"
    get "reports" => "reports#index"
    get "reports/orders" => "reports#orders"
    get "reports/inventory" => "reports#inventory"
    get "logout" => "sessions#destroy"
  end

  # JSON API (moved under /api to avoid route collisions with HTML UI)
  scope "/api", as: :api, defaults: { format: :json } do
    resources :skus, only: %i[index create]
    resources :warehouses, only: %i[index create]

    get "inventory" => "inventory#index"

    resources :orders, only: %i[create show] do
      member do
        post :cancel
        post :fulfill
      end
    end

    post "payments/create_order" => "payments#create_order"
    post "payments/verify" => "payments#verify"
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
