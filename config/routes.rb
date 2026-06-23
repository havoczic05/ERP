Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Authentication routes
  resource :session, only: %i[new create destroy]
  get "login",  to: "sessions#new",     as: :login
  delete "logout", to: "sessions#destroy", as: :logout

  # Defines the root path route ("/")
  root "sales#index"

  resources :users

  resources :clients do
    collection do
      get :search
    end
  end

  resources :warehouses

  resources :products do
    collection do
      get :search
    end
  end

  resources :sales do
    member do
      post :annul
      post :convert_to_sale
    end
  end

  resources :installments, only: [] do
    resources :amortizations, only: [ :create ]
  end

  get "accounts_receivable", to: "accounts_receivable#index", as: :accounts_receivable

  get "dashboard", to: "dashboards#show", as: :dashboard

  resource :company_settings, only: %i[show edit update]
end
