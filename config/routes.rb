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
      get :filters
    end
  end

  resources :warehouses

  resources :products do
    collection do
      get :search
    end
  end

  resources :sales do
    collection do
      get :filters
    end

    member do
      post :annul
      get  :convert
      post :convert_to_sale
    end
  end

  resources :installments, only: [] do
    resources :amortizations, only: [ :create ]
  end

  get "accounts_receivable", to: "accounts_receivable#index", as: :accounts_receivable
  get "accounts_receivable/filters", to: "accounts_receivable#filters", as: :filters_accounts_receivable

  get "dashboard", to: "dashboards#show", as: :dashboard

  resource :company_settings, only: %i[show edit update]

  # Import UI routes — admin-only, scoped under /config/importar
  scope "/config/importar", controller: :imports, as: :import do
    get  "productos",          action: :new_products,    as: :new_products
    post "productos",          action: :create_products, as: :create_products
    get  "productos/plantilla", action: :product_template, as: :product_template
    get  "clientes",           action: :new_clients,     as: :new_clients
    post "clientes",           action: :create_clients,  as: :create_clients
    get  "clientes/plantilla", action: :client_template, as: :client_template
  end

  # Backup (pg_dump) — admin-only, scoped under /config/respaldo
  scope "/config/respaldo", controller: :backups, as: :backup do
    get  "/", action: :new,    as: :new
    post "/", action: :create, as: :create
    get  "download", action: :download, as: :download
  end
end
