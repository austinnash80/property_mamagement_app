# One page of the private scratchpad. Scoped to its author everywhere: see
# Family::NotesController#scope, which is the only way the app loads these.
class Family::Note < ApplicationRecord
  belongs_to :user

  validates :title, presence: true

  scope :for_user, ->(user) { where(user_id: user&.id) }
  scope :ordered,  -> { order(updated_at: :desc) }

  # The first line or so, for the card on the index.
  def preview(limit = 180)
    body.to_s.strip.gsub(/\s+/, " ").truncate(limit)
  end
end
