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

  changes do
    change AshPhoenixStarter.Changes.SetTenant
    
    # Automatically manage UTC microsecond timestamp mutations on lifecycle events
    change set_attribute(:inserted_at, &DateTime.utc_now/0), on: :create
    change set_attribute(:updated_at, &DateTime.utc_now/0), on: [:create, :update]
  end

  # =====================================================================
  # 📊 Attributes Definition Block
  # =====================================================================
  attributes do
    uuid_primary_key :id, writable?: false

    attribute :name, :string do
      allow_nil? false
      public? true
      # Enforce basic validation strings to match form entry expectations
      constraints min_length: 2, max_length: 100
    end

    attribute :country_code, :string do
      allow_nil? false
      public? true
      # Restrict strings to standard ISO-2 character codes
      constraints max_length: 2, match: ~r/^[A-Z]{2}$/
    end

    attribute :inserted_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :updated_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end
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
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :country_code, :user_id]
    end

    update :update do
      primary? true
      accept [:name, :country_code, :user_id]
      
      change into_context(:country_code, &String.upcase/1)
    end
  end

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
