# A development account to sign in with: bin/rails db:seed
# Being the first account, it runs the studio (see User). Never in production.
if Rails.env.development?
  User.find_or_create_by!(email_address: "dev@example.com") do |user|
    user.name = "Dev"
    user.password = "password123"
  end
end
