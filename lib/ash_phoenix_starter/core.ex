defmodule AshPhoenixStarter.Core do
  use Ash.Domain,
    otp_app: :AshPhoenixStarter

  resources do
    resource AshPhoenixStarter.Settings.Configuration
  end
end
