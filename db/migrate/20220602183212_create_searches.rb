class CreateSearches < ActiveRecord::Migration[6.1]
  def change
    create_table :searches do |t|
      t.string :property
      t.string :accounting_type
      t.string :description
      t.date :date_range_a
      t.date :date_range_b
      t.string :field_1
      t.string :field_2
      t.string :field_3

      t.timestamps
    end
  end
end
