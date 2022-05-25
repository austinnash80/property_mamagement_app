class CreateAccountingLists < ActiveRecord::Migration[6.1]
  def change
    create_table :accounting_lists do |t|
      t.string :accounting_type
      t.string :vendor
      t.decimal :amount
      t.text :notes

      t.timestamps
    end
  end
end
