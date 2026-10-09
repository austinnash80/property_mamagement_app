# Tags label a task across lists ("Home improvement", "Errand"). Free text,
# comma separated, same shape as design_notes.tags.
# created_by_id records who added the task, which a shared list wants on the
# detail page alongside who completed it.
class AddTagsToFamilyTasks < ActiveRecord::Migration[6.1]
  def change
    add_column :family_tasks, :tags, :string
    add_column :family_tasks, :created_by_id, :bigint
    add_index  :family_tasks, :created_by_id
    add_foreign_key :family_tasks, :users, column: :created_by_id, on_delete: :nullify
  end
end
