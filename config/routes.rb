Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "ui/orders#new"

  namespace :ui do
    resources :orders, only: %i[index new create show]
  end

  namespace :admin do
    root "dashboard#index"
    resources :inventory, only: [:index]
    resources :skus, only: [:index]
    resources :warehouses, only: [:index]
  end

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

  # Defines the root path route ("/")
  # root "posts#index"
end
