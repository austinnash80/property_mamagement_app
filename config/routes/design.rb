# Design Center — an independent section of the app for architectural design:
# design concepts, idea notes, an inspiration/reference image library and, in
# later phases, floor plans and renderings.
#
# Served under the /design path today. It follows the same shape as the
# portfolio section (see config/routes/portfolio.rb) so it can be moved to its
# own subdomain later by wrapping this block in `constraints(subdomain: ...)`
# and changing `path:` to "".
#
# Loaded from config/routes.rb via `draw(:design)`.

namespace :design, path: "design" do
  root to: "dashboard#index"

  # Concepts: one container per design idea (a floor plan, a kitchen, a whole
  # house). Notes and images can belong to a concept or stand alone.
  resources :concepts do
    # Floor plans are drawn per concept. Shallow: new/create/index nest under
    # the concept, show (the editor)/edit/update/destroy are top-level.
    resources :floor_plans, shallow: true
  end
  resources :floor_plans, only: :index   # all plans across concepts

  resources :notes do
    member { patch :toggle_pin }
  end

  resources :images
end
