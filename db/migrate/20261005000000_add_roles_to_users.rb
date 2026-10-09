# Family members get their own logins, so a User is no longer automatically
# allowed everywhere. Roles:
#   owner  - full access plus managing the family accounts (Austin)
#   full   - every section, but cannot manage accounts
#   family - the Family App only; the property, portfolio and design sections
#            stay hidden
# The column defaults to "family" so an account created without thinking about
# it gets the least access, not the most.
class AddRolesToUsers < ActiveRecord::Migration[6.1]
  def up
    add_column :users, :role, :string, null: false, default: "family"
    add_column :users, :name, :string
    add_index  :users, :role

    # Every account that existed before roles did belongs to the owner.
    execute "UPDATE users SET role = 'owner'"
  end

  def down
    remove_column :users, :role
    remove_column :users, :name
  end
end
