defmodule AshPhoenixStarter.Core do
  use Ash.Domain,
    otp_app: :AshPhoenixStarter,
    extensions: [AshOps]

  resources do
    resource AshPhoenixStarter.Core.FileAsset
  end
end