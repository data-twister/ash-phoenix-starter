defmodule AshPhoenixStarter.Merchants.Merchant do
  use Ash.Resource,
    otp_app: :ash_phoenix_starter,
    domain: AshPhoenixStarter.Merchants,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "merchants"
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
    # A merchant belongs to a user account
    belongs_to :user, AshPhoenixStarter.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      public? true
    end

    # A merchant belongs to a geographic/operational region
    belongs_to :region, AshPhoenixStarter.Regions.Region do
      attribute_type :uuid
      allow_nil? false
      public? true
    end

    # Plugs into the stock template layout to view low stock records
    has_many :low_stock_products, AshPhoenixStarter.Merchants.Product do
      public? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :user_id, :region_id]
    end

    update :update do
      primary? true
      accept [:name, :user_id, :region_id]
    end
  end
end
