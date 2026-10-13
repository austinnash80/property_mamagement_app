class AddArchivedAtToFamilyListsAndTasks < ActiveRecord::Migration[6.1]
  def change
    add_column :family_lists, :archived_at, :datetime
    add_index :family_lists, :archived_at
    add_column :family_tasks, :archived_at, :datetime
    add_index :family_tasks, :archived_at
  end
end
