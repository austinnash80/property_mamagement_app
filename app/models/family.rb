# Namespace for the Family App section. Independent of the property-management,
# portfolio and design tables; every table here is prefixed family_.
module Family
  def self.table_name_prefix
    "family_"
  end

  # The app as a whole runs in UTC (config.time_zone is unset), which would make
  # a task due today read as overdue from 5pm local onwards. Due dates are a
  # household thing, so the Family section asks a local clock what "today" is
  # rather than changing the global zone under the accounting and booking code.
  ZONE = "America/Los_Angeles".freeze

  def self.today
    Time.find_zone(ZONE).today
  end

  # Picked to sit alongside the property-management blue.
  LIST_COLORS = %w[#2563eb #0f766e #b45309 #7c3aed #be123c #475569].freeze

  # Offered in the tag box before any task has been tagged. Tags are free text:
  # these are only suggestions, and anything typed becomes a suggestion later.
  # "Home improvement" is a list, not a tag, so it isn't suggested here.
  SUGGESTED_TAGS = ["Errand", "Appointment", "School", "Bills", "Yard"].freeze

  # Household reference: the categories entries are filed under, in the order
  # they are shown.
  REFERENCE_CATEGORIES = [
    "Wifi & codes", "Home systems", "Paint & finishes",
    "Contacts", "Utilities & accounts", "Other"
  ].freeze

  # Places to go: kind => label.
  PLACE_KINDS = {
    "restaurant" => "Restaurant",
    "coffee"     => "Coffee & bakery",
    "bar"        => "Bar & brewery",
    "shop"       => "Shop",
    "market"     => "Market",
    "activity"   => "Activity",
    "outdoors"   => "Park & outdoors",
    "other"      => "Other"
  }.freeze

  # "Home improvement, yard" -> ["Home improvement", "yard"]
  def self.tag_list(str)
    str.to_s.split(",").map(&:strip).reject(&:blank?)
  end
end
