namespace :users do
  desc "Create a user with a temporary password. rails 'users:create[email]'"
  task :create, [:email] => :environment do |_t, args|
    abort "Usage: rails 'users:create[email]'" if args[:email].blank?
    temp = SecureRandom.base58(14)
    user = User.create!(email: args[:email], password: temp)
    puts "created #{user.email}  temporary password: #{temp}  (change it at /account/edit)"
  end

  desc "Reset a user's password to a new temporary one. rails 'users:reset_password[email]'"
  task :reset_password, [:email] => :environment do |_t, args|
    user = User.find_by!(email: args[:email].to_s.strip.downcase)
    temp = SecureRandom.base58(14)
    user.update!(password: temp); user.rotate_remember_token!
    puts "#{user.email}  temporary password: #{temp}  (all browsers signed out)"
  end
end
