class AddDatetoAccounting < ActiveRecord::Migration[6.1]
  def change
    date :record_date
  end
end
