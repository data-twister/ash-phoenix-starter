defmodule AshPhoenixStarter.Settings.TenantConfiguration do
  @moduledoc """
  An Ash Framework resource representing a tenant-scoped key-value configuration entry
  persisted in the PostgreSQL database.

  `TenantConfiguration` acts as the persistent storage layer for tenant-specific
  overrides (such as custom CDN domains, branding, or operational rules) while leveraging
  attribute-based multi-tenancy (`team_id`) for strict data isolation.
  """

  use Ash.Resource,
    domain: AshPhoenixStarter.Settings,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "settings"
    repo AshPhoenixStarter.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      description "Creates a new tenant-scoped configuration setting."
      accept [:key, :value, :type]
      primary? true
    end

    update :update do
      description "Updates an existing tenant configuration setting."
      accept [:value, :type]
    end
  end

  preparations do
    prepare AshPhoenixStarter.Preparations.SetTenant
  end

  changes do
    change AshPhoenixStarter.Changes.SetTenant
  end

  validations do
    validate one_of(:type, ["string", "integer", "boolean", "atom", "float"]),
      message: "must be a supported primitive type descriptor"
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :key, :string do
      description "The unique lookup key for the setting within the tenant scope."
      allow_nil? false
      public? true
    end

    attribute :value, :string do
      description "The serialized string value of the configuration option."
      allow_nil? false
      public? true
    end

    attribute :type, :string do
      description "The primitive type indicator used to cast the value back to its native Elixir form."
      allow_nil? false
      default "string"
      public? true
    end

    timestamps()
  end

  identities do
    # Ensures keys are unique *per tenant* (via team_id context/multitenancy scoping)
    identity :unique_tenant_key, [:key], message: "configuration keys must be unique per tenant"
  end
end
