# A private scratchpad for the Family App: half-formed ideas, brainstorms and
# drafts that the rest of the household has no reason to see.
#
# Unlike every other family_ table, a row here belongs to exactly one person.
# user_id is NOT NULL and the controller only ever queries through it, so a note
# is invisible to the other members - the owner account included.
class CreateFamilyNotes < ActiveRecord::Migration[6.1]
  def change
    create_table :family_notes do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :title, null: false
      t.text   :body
      t.timestamps
    end
    add_index :family_notes, %i[user_id updated_at]
  end
end
