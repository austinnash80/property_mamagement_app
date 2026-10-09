# Family App — an independent section of the app. Unlike the other sections it
# is open to family-role accounts (see ApplicationController#require_full_access),
# which is why every family URL lives under this one namespace.
#
# It follows the same shape as the portfolio and design sections (see
# config/routes/portfolio.rb) so it can move to its own subdomain later by
# wrapping this block in `constraints(subdomain: ...)` and changing `path:` to "".
#
# Loaded from config/routes.rb via `draw(:family)`.

namespace :family, path: "family" do
  root to: "dashboard#index"

  # /family/todo is the to-do overview: pick a view (a list, a tag or a person)
  # and it opens the matching task list at /family/tasks.
  get "todo", to: "tasks#overview", as: :todo

  # Tasks have a detail page (show): the row in the list links to it.
  resources :tasks do
    member { patch :toggle }
  end

  # Calendar: /family/calendar is the month grid, events have their own pages.
  get "calendar", to: "events#index", as: :calendar
  resources :events, except: :index

  # Household reference: wifi, codes, filter sizes, paint colors, phone numbers.
  # Everything lives on the index page, so there is no show action.
  resources :references, path: "reference", except: :show do
    member { patch :toggle_pin }
  end

  # Andie: doctor numbers, addresses, school details, everything kept for Andie.
  # Everything lives on the index page, so there is no show action.
  resources :andie_entries, path: "andie", except: :show

  # Places to go: restaurants, shops, the farmers market.
  resources :places do
    member do
      patch :visit      # been there / not yet
      patch :favorite
    end
  end

  # A private scratchpad, one per person: brainstorms and half-formed ideas the
  # rest of the household has no reason to see. Scoped to the signed-in user in
  # Family::NotesController - there is no way to read someone else's.
  resources :notes, path: "notebook", except: :show

  # Push notifications: the browser registers/unregisters a device here.
  resource :push_subscription, only: %i[create destroy], path: "push" do
    post :test
  end

  resources :lists, except: :show

  # Family logins. Owner-only: see Family::MembersController.
  resources :members, except: :show
end
