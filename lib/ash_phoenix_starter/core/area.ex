defmodule AshPhoenixStarter.Core.Area do
  use Ash.Resource,
    domain: AshPhoenixStarter.Core,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "areas"
    repo AshPhoenixStarter.Repo
  end

  attributes do
    uuid_primary_key :id, writable?: false

    attribute :name, :string do
      allow_nil? false
      public? true # e.g., "Downtown Delivery Zone Suite A"
    end
    
    attribute :postal_code_prefix, :string do
      allow_nil? true
      public? true # e.g., "857" for localized structural matching
    end
  end

  relationships do
    # Every localized Area belongs structurally to a rigid Region parent boundary
    belongs_to :region, AshPhoenixStarter.Core.Region do
      attribute_type :uuid
      allow_nil? false
      public? true
    end
  end
end
