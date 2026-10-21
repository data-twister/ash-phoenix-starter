defmodule AshPhoenixStarter.Core.Region do
  use Ash.Resource,
    domain: AshPhoenixStarter.Core,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "regions"
  end

  attributes do
    uuid_primary_key :id, writable?: false


    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :country_code, :string do
      allow_nil? false
      public? true
    end

    # Database-managed timestamps (FIXED: block syntax adjusted)
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
    has_many :merchants, AshPhoenixStarter.Accounts.Merchant do
      public? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :country_code]
    end

    update :update do
      primary? true
      accept [:name, :country_code]
    end
  end
end
