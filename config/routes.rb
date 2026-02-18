Rails.application.routes.draw do
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
