alias Ash.Generator
alias AshPhoenixStarter.Generators.User

super_user =
  List.first(Application.get_env(:AshPhoenixStarter, :super_users)) || "admin@example.com"

default_password = System.get_env("DEFAULT_ADMIN_PASSWORD") || "AdminPassword123!"

IO.puts("Seeding admin user #{super_user}...")

# Generate and insert an admin user using the UserGenerator
admin_user =
  User.user(
    username: "admin",
    email: super_user,
    password: default_password,
    password_confirmation: default_password
  )
  |> Ash.Generator.generate()

IO.puts("Successfully created admin user: #{admin_user.username} (#{admin_user.email})")

users = Generator.generate_many(User.user(), 3)

AshPhoenixStarter.SelfCertGenerator.generate_self_signed()
