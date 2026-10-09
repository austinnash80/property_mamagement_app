# Due dates were dropped from the to-do list (2026-10-08): tasks are just open
# or done, in list order. The calendar and the morning digest no longer pull
# tasks in, so nothing reads this column any more.
class RemoveDueOnFromFamilyTasks < ActiveRecord::Migration[6.1]
  def change
    remove_index  :family_tasks, :due_on
    remove_column :family_tasks, :due_on, :date
  end
end
