defmodule AshPhoenixStarter.Core.Region do
  use Ash.Resource,
    domain: AshPhoenixStarter.Core,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "regions"
  end

  attributes do
    uuid_primary_key :id do
      generated? true
      allow_nil? true
      writable? false
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    # 1. ADDED: Clear country grouping scope matching your new core framework semantics
    attribute :country_code, :string do
      allow_nil? false
      public? true
    end

    # Database-managed timestamps
    attribute :inserted_at, :utc_datetime_usec do
      generated? true
      allow_nil? true
      writable? false
    end

    attribute :updated_at, :utc_datetime_usec do
      generated? true
      allow_nil? true
      writable? false
    end
  end

  relationships do
    has_many :merchants, AshPhoenixStarter.Accounts.Merchant do
      public? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      # 2. UPDATED: Whitelist country code parameters inside your data ingest actions
      accept [:name, :country_code]
    end

    update :update do
      primary? true
      accept [:name, :country_code]
    end
  end
end
