defmodule AshPhoenixStarter.Accounts.Merchant do
  use Ash.Resource,
    domain: AshPhoenixStarter.Accounts,
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
    # Fixed: Passing options inline to uuid_primary_key is the safest and cleanest pattern in Ash
    uuid_primary_key :id, writable?: false

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    # 1. ADDED: Geographic scoping attributes matching the mapping engine requirements
    attribute :country_code, :string do
      allow_nil? false
      public? true
    end

    attribute :region_name, :string do
      allow_nil? false
      public? true
    end

    # Database-managed timestamps (Fixed: allow_nil? syntax inside block)
    attribute :inserted_at, :utc_datetime_usec do
      allow_nil? true
      public? false
    end

    attribute :updated_at, :utc_datetime_usec do
      allow_nil? true
      public? false
    end
  end

  relationships do
    belongs_to :user, AshPhoenixStarter.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      public? true
    end

    belongs_to :region, AshPhoenixStarter.Core.Region do
      attribute_type :uuid
      allow_nil? false
      public? true
    end

    # 2. FIXED: Point to the new updated Product module namespace path
    has_many :low_stock_products, AshPhoenixStarter.Merchants.Product do
      public? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      # Include new geographic properties in your creation whitelist parameters
      accept [:name, :country_code, :region_name, :user_id, :region_id]
    end

    update :update do
      primary? true
      accept [:name, :country_code, :region_name, :user_id, :region_id]
    end
  end
end
