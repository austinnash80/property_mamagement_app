# Project Portfolio — an independent section of the app.
#
# Today it is served under the /portfolio path of the main app. To move it to
# its own subdomain later (e.g. portfolio.yourdomain.com):
#   1. Add the subdomain to Heroku (`heroku domains:add portfolio.yourdomain.com`)
#      and point DNS at the app.
#   2. Change the two lines marked SUBDOMAIN below, so the block becomes
#        constraints(subdomain: "portfolio") do
#          namespace :portfolio, path: "" do
#      and add `end` for the constraints block.
# Controllers, models, views and helpers need no changes; every URL helper
# (portfolio_projects_path, etc.) keeps the same name.
#
# Loaded from config/routes.rb via `draw(:portfolio)`.

# SUBDOMAIN: wrap in `constraints(subdomain: "portfolio") do`
namespace :portfolio, path: "portfolio" do   # SUBDOMAIN: change path to ""
  root to: "properties#index"

  resources :properties do
    collection { get :export_csv }
  end

  # Inbox: harvested source documents awaiting triage
  get "inbox", to: "source_documents#index", as: :inbox
  resources :source_documents, only: %i[index show update destroy] do
    collection { post :bulk; get :export_csv }
    member     { post :promote }
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
