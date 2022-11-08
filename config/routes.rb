Rails.application.routes.draw do
  resources :booking_days
  resources :searches
  resources :accounting_lists
  resources :accountings
  resources :bookings
  resources :properties
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get 'pages/homepage'
  get 'pages/manage_property'
  get 'pages/reports'
  root to: "pages#homepage"
end
