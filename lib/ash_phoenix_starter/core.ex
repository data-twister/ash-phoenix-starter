defmodule AshPhoenixStarter.Core do
  use Ash.Domain,
    otp_app: :ash_phoenix_starter,
    extensions: [AshOps]

  resources do
    resource AshPhoenixStarter.Core.Area
    resource AshPhoenixStarter.Core.FileAsset
    resource AshPhoenixStarter.Core.Product
    resource AshPhoenixStarter.Core.Region
    resource AshPhoenixStarter.Core.RegionLocation
  end
end
