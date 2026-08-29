defmodule AshPhoenixStarter.Settings do
  use Ash.Domain,
    otp_app: :AshPhoenixStarter,
    extensions: [AshOps]

  resources do
    resource AshPhoenixStarter.Settings.Setting
    resource AshPhoenixStarter.Settings.TenantConfiguration
    resource AshPhoenixStarter.Settings.Billing
  end
end
