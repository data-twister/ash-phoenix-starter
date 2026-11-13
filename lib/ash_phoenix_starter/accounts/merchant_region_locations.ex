defmodule AshPhoenixStarter.Accounts.MerchantRegionLocation do
  use Ash.Resource,
    domain: AshPhoenixStarter.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "merchant_region_locations"
    repo AshPhoenixStarter.Repo

     references do
      reference :merchant, on_delete: :delete
      reference :region_location, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end

  preparations do
    prepare AshPhoenixStarter.Preparations.SetTenant
  end

  changes do
    change AshPhoenixStarter.Changes.SetTenant
  end

  identities do
    identity :unique_merchant_location, [:merchant_id, :region_location_id]
  end

  attributes do
    uuid_primary_key :id, writable?: false
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :merchant, AshPhoenixStarter.Accounts.Merchant do
      attribute_type :uuid
      allow_nil? false
      primary_key? true
      public? true
    end

    belongs_to :region_location, AshPhoenixStarter.Core.RegionLocation do
      attribute_type :uuid
      allow_nil? false
      primary_key? true
      public? true
    end
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
