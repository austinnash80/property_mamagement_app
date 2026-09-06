Rails.application.routes.draw do

  # ---- Project Portfolio (independent section) ----
  namespace :portfolio do
    root to: "properties#index"
    resources :properties do
      collection { get :export_csv }
    end
    resources :vendors do
      collection { get :export_csv }
    end
    resources :projects do
      collection { get :export_csv }
      resources :work_items, shallow: true
      resources :expenses,   shallow: true do
        collection { get :export_csv }
      end
      resources :photos,     shallow: true
      resources :documents,  shallow: true
    end
  end
  resources :booking_days
  resources :searches
  resources :accounting_lists do
    collection do
      get  :export_csv
      post :import_csv
    end
  end

  resources :accountings do
    collection do
      get  :export_csv
      post :import_csv
    end
  end
  resources :bookings do
    collection do
      get  :export_csv
      post :import_csv
    end
  end
  resources :properties do
    collection do
      get  :export_csv
      post :import_csv
    end
  end

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get 'pages/homepage'
  get 'pages/manage_property'
  get 'pages/reports'
  get 'pages/streaming_passwords'
  root to: "pages#homepage"
end
