defmodule AshPhoenixStarter.Accounts do
  use Ash.Domain,
    otp_app: :ash_phoenix_starter,
    extensions: [AshOps]

  resources do
    resource AshPhoenixStarter.Accounts.Token
    resource AshPhoenixStarter.Accounts.User
    resource AshPhoenixStarter.Accounts.Team
    resource AshPhoenixStarter.Accounts.UserTeam

    resource AshPhoenixStarter.Accounts.Group
    resource AshPhoenixStarter.Accounts.UserGroup
    resource AshPhoenixStarter.Accounts.GroupPermission

    resource AshPhoenixStarter.Accounts.UserImpersonation

    resource AshPhoenixStarter.Accounts.Invitation

    resource AshPhoenixStarter.Accounts.UserNotification do
      define :notify, action: :create
    end
  end
end
