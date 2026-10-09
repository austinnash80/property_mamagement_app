# Site home: a hub page linking to each section of the site. Each section keeps
# its own landing page (/pages/homepage, /portfolio, /design, /family); this
# page just points at them and shows a count or two for context.
class HomeController < ApplicationController
  skip_before_action :require_full_access   # the hub shows only the sections you can open
  layout "home"

  def index
    # Family-only accounts have exactly one section, so send them straight to it
    # rather than showing a hub with a single card on it.
    return redirect_to family_root_path if current_user&.family_only?

    @counts = {
      properties: Property.count,
      projects:   Portfolio::Project.count,
      concepts:   Design::Concept.count,
      open_tasks: Family::Task.unfinished.count
    }
  end
end
