defmodule AshPhoenixStarter.Accounts do
  use Ash.Domain,
    otp_app: :AshPhoenixStarter,
    extensions: [AshOps]

  mix_tasks do
    action AshPhoenixStarter.Generators.Account, :generate_user, :generate_user,
      arguments: [:count]
  end

  resources do
    resource AshPhoenixStarter.Accounts.Token
    resource AshPhoenixStarter.Accounts.User
    resource AshPhoenixStarter.Accounts.Team
    resource AshPhoenixStarter.Accounts.UserTeam

    resource AshPhoenixStarter.Accounts.Group
    resource AshPhoenixStarter.Accounts.UserGroup
    resource AshPhoenixStarter.Accounts.GroupPermission

    resource AshPhoenixStarter.Accounts.UserImpersonation

    resource AshPhoenixStarter.Generators.Account
  end
end
