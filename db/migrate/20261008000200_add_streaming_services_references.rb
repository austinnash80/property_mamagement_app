# "Streaming services" joins the household-reference categories. Netflix and HBO
# had been filed wherever was handy ("Wifi & codes", "Other"): move them across,
# and add either one if it's missing so both are there from the start.
class AddStreamingServicesReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE family_references
         SET category = 'Streaming services', title = btrim(title), updated_at = NOW()
       WHERE lower(title) LIKE '%netflix%' OR lower(title) LIKE '%hbo%'
    SQL

    %w[Netflix HBO].each do |name|
      execute <<~SQL
        INSERT INTO family_references (title, category, created_at, updated_at)
        SELECT '#{name}', 'Streaming services', NOW(), NOW()
         WHERE NOT EXISTS (
           SELECT 1 FROM family_references WHERE lower(title) LIKE '%#{name.downcase}%'
         )
      SQL
    end
  end

  def down
    execute "UPDATE family_references SET category = 'Other' WHERE category = 'Streaming services'"
  end
end
