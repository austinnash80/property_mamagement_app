class CreateUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :remember_token, null: false     # value of the persistent sign-in cookie
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :remember_token, unique: true
  end
end
