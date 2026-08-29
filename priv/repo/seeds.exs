alias Ash.Generator
alias AshPhoenixStarter.Generators.User
alias AshPhoenixStarter.Generators.Team

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

team =
  AshPhoenixStarter.Accounts.Team
  |> Ash.Changeset.for_create(
    :create,
    %{
      name: "Admin",
      domain: "admin",
      description: "Primary HOA management workspace"
    },
    actor: admin_user
  )
  |> Ash.create!()

group_attrs = [
  %{name: "Admin", description: "Admin Group"},
  %{name: "User", description: "Non Admin User"},
  %{name: "Owner", description: "Owner"},
  %{name: "Tenant", description: "Tenant"}
]

groups = Ash.Seed.seed!(AshPhoenixStarter.Accounts.Group, group_attrs, tenant: team.domain)

user_groups = Enum.map(groups, fn x -> %{user_id: admin_user.id, group_id: x.id} end)

AshPhoenixStarter.Utils.sync_user_groups_for_seed(user_groups, team.domain)

IO.puts("Successfully created admin user: #{admin_user.username} (#{admin_user.email})")

users = Generator.generate_many(User.user(), 3)

Enum.each(users, fn u ->
  local_part = u.email |> String.split("@") |> hd()

  team =
    AshPhoenixStarter.Accounts.Team
    |> Ash.Changeset.for_create(
      :create,
      %{
        name: local_part,
        domain: local_part,
        description: local_part
      },
      actor: u
    )
    |> Ash.create!()

  groups = Ash.Seed.seed!(AshPhoenixStarter.Accounts.Group, group_attrs, tenant: team.domain)

  user_groups = Enum.map(groups, fn x -> %{user_id: u.id, group_id: x.id} end)

  AshPhoenixStarter.Utils.sync_user_groups_for_seed(user_groups, team.domain)
end)

AshPhoenixStarter.SelfCertGenerator.generate_self_signed()
