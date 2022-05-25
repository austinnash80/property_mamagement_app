class CreateProperties < ActiveRecord::Migration[6.1]
  def change
    create_table :properties do |t|
      t.string :nickname
      t.string :address
      t.string :picture
      t.decimal :bed
      t.decimal :bath
      t.integer :sq_ft
      t.string :notes

      t.timestamps
    end
  end
end
