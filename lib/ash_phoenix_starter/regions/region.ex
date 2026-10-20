defmodule AshPhoenixStarter.Regions.Region do
  use Ash.Resource,
    otp_app: :ash_phoenix_starter,
    domain: AshPhoenixStarter.Regions,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "regions"
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
    has_many :merchants, AshPhoenixStarter.Merchants.Merchant do
      public? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name]
    end

    update :update do
      primary? true
      accept [:name]
    end
  end
end
