class Family::BaseController < ApplicationController
  # The one section family-role accounts can use.
  skip_before_action :require_full_access

  include FamilyNotifies

  layout "family"
end
