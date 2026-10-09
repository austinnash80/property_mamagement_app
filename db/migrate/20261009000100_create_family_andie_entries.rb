# Andie: the facts kept for Andie — the pediatrician's number, the home address,
# school details. Same shape as family_references (title / short value / notes)
# but its own table, so it can grow in its own direction without tangling the
# household reference.
class CreateFamilyAndieEntries < ActiveRecord::Migration[6.1]
  def change
    create_table :family_andie_entries do |t|
      t.string  :title,   null: false
      t.string  :section, null: false, default: "Other"
      t.string  :value
      t.text    :notes
      t.bigint  :updated_by_id
      t.timestamps
    end
    add_index :family_andie_entries, :section
    add_foreign_key :family_andie_entries, :users, column: :updated_by_id, on_delete: :nullify
  end
end
