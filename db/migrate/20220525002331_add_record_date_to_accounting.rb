class AddRecordDateToAccounting < ActiveRecord::Migration[6.1]
  def change
    add_column :accountings, :record_date, :date
  end
end
