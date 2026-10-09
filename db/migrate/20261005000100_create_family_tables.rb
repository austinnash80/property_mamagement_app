class CreateFamilyTables < ActiveRecord::Migration[6.1]
  def change
    create_table :family_lists do |t|
      t.string  :name,     null: false
      t.string  :color,    null: false, default: "#2563eb"
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :family_lists, :position

    create_table :family_tasks do |t|
      t.references :list, null: false, foreign_key: { to_table: :family_lists }
      t.string   :title, null: false
      t.text     :notes
      t.bigint   :assignee_id            # users.id, optional: unassigned tasks are fine
      t.date     :due_on
      t.datetime :done_at                # null = still open; a timestamp = done
      t.bigint   :done_by_id             # who checked it off
      t.integer  :position, null: false, default: 0
      t.timestamps
    end
    add_index :family_tasks, :assignee_id
    add_index :family_tasks, :due_on
    add_index :family_tasks, :done_at
    add_foreign_key :family_tasks, :users, column: :assignee_id, on_delete: :nullify
    add_foreign_key :family_tasks, :users, column: :done_by_id,  on_delete: :nullify
  end
end
