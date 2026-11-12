defmodule AshPhoenixStarter.Accounts.VendorRegionLocation do
  use Ash.Resource,
    domain: AshPhoenixStarter.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "vendor_region_locations"
    repo AshPhoenixStarter.Repo
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
    identity :unique_vendor_location, [:vendor_id, :region_location_id]
  end

  attributes do
    uuid_primary_key :id, writable?: false
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :vendor, AshPhoenixStarter.Accounts.Vendor do
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
