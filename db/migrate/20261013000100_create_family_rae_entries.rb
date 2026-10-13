# Rae: the facts kept for Rae, the dog — the vet's number, her food and meds,
# the groomer. Same shape as family_andie_entries (title / short value / notes)
# but its own table.
class CreateFamilyRaeEntries < ActiveRecord::Migration[6.1]
  def change
    create_table :family_rae_entries do |t|
      t.string  :title,   null: false
      t.string  :section, null: false, default: "Other"
      t.string  :value
      t.text    :notes
      t.bigint  :updated_by_id
      t.timestamps
    end
    add_index :family_rae_entries, :section
    add_foreign_key :family_rae_entries, :users, column: :updated_by_id, on_delete: :nullify
  end
end
