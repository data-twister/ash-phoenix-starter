defmodule AshPhoenixStarter.Accounts.Customer do
  use Ash.Resource,
    domain: AshPhoenixStarter.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "Customers"
    repo AshPhoenixStarter.Repo
  end

  multitenancy do
    strategy :context
  end

  preparations do
    prepare AshPhoenixStarter.Preparations.SetTenant
  end

  # =====================================================================
  # 📊 Attributes Definition Block
  # =====================================================================
  attributes do
    uuid_primary_key :id, writable?: false

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 2, max_length: 100
    end

    attribute :country_code, :string do
      allow_nil? false
      public? true
      constraints max_length: 2, match: ~r/^[A-Z]{2}$/
    end

    # Automatically handles inserted_at and updated_at with microsecond precision
    timestamps(type: :utc_datetime_usec, public?: true)
  end

  # =====================================================================
  # 🔗 Relationships Matrix
  # =====================================================================
  relationships do
    belongs_to :user, AshPhoenixStarter.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      public? true
    end
  end

  # =====================================================================
  # 🎬 Actions Lifecycle Engine
  # =====================================================================
  actions do
    # GLOBAL CHANGES MUST LIVE INSIDE ACTIONS
    changes do
      change AshPhoenixStarter.Changes.SetTenant
    end

    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :country_code, :user_id]
    end

    update :update do
      primary? true
      accept [:name, :country_code, :user_id]
    end
  end

  # =====================================================================
  # 🔒 Policies
  # =====================================================================
  policies do
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end
end
