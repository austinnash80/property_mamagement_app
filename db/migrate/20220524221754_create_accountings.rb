class CreateAccountings < ActiveRecord::Migration[6.1]
  def change
    create_table :accountings do |t|
      t.integer :property_id
      t.string :r_e
      t.string :description
      t.decimal :amount
      t.text :notes

      t.timestamps
    end
  end
end
