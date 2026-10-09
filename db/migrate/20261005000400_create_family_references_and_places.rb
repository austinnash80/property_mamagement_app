# Two small reference features for the Family App.
#
# family_references: the things you currently text each other or re-look-up —
#   wifi password, HVAC filter size, paint colors, garage code, the vet's number.
#   `value` is the short answer, `notes` the context around it.
#
# family_places: somewhere to keep "we should try that" — restaurants, shops,
#   the farmers market. visited_at null means it's still on the want-to-go list.
class CreateFamilyReferencesAndPlaces < ActiveRecord::Migration[6.1]
  def change
    create_table :family_references do |t|
      t.string  :title,    null: false
      t.string  :category, null: false, default: "Other"
      t.string  :value
      t.text    :notes
      t.boolean :pinned,   null: false, default: false
      t.bigint  :updated_by_id
      t.timestamps
    end
    add_index :family_references, :category
    add_index :family_references, :pinned
    add_foreign_key :family_references, :users, column: :updated_by_id, on_delete: :nullify

    create_table :family_places do |t|
      t.string   :name, null: false
      t.string   :kind, null: false, default: "other"
      t.string   :area                      # neighbourhood or city, free text
      t.string   :url
      t.text     :notes
      t.datetime :visited_at                # null = still want to go
      t.boolean  :favorite, null: false, default: false
      t.bigint   :created_by_id
      t.timestamps
    end
    add_index :family_places, :kind
    add_index :family_places, :visited_at
    add_foreign_key :family_places, :users, column: :created_by_id, on_delete: :nullify
  end
end
