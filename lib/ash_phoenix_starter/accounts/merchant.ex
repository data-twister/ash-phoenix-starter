defmodule AshPhoenixStarter.Accounts.Merchant do
  use Ash.Resource,
    domain: AshPhoenixStarter.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "merchants"
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
      # Protect against empty strings or blown-out form entry text payloads
      constraints min_length: 2, max_length: 100
    end

    attribute :country_code, :string do
      allow_nil? false
      public? true
      # Strictly validate uppercase country codes using standard ISO-2 formats
      constraints max_length: 2, match: ~r/^[A-Z]{2}$/
    end

    attribute :region_name, :string do
      allow_nil? false
      public? true
      constraints min_length: 2, max_length: 100
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

    belongs_to :region, AshPhoenixStarter.Core.Region do
      attribute_type :uuid
      allow_nil? false
      public? true
    end

    has_many :low_stock_products, AshPhoenixStarter.Core.Product do
      public? true
    end
  end

  # =====================================================================
  # 🧮 Derived Computations & Calculations
  # =====================================================================
  calculations do
    # Compiles directly down into subqueries for lightning-fast database sorting
    calculate :low_stock_count, :integer, expr(count(low_stock_products)) do
      public? true
    end

    # Real-time boolean comparison checking structural alignment
    calculate :local_region?, :boolean, expr(region.name == region_name) do
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
      accept [:name, :country_code, :region_name, :user_id, :region_id]
      
      # Clean data entry tracking strings automatically before write pipeline commits
      change into_context(:country_code, &String.upcase/1)
    end

    update :update do
      primary? true
      accept [:name, :country_code, :region_name, :user_id, :region_id]
      
      change into_context(:country_code, &String.upcase/1)
    end

    # Custom dashboard endpoint supporting clean data slicing out-of-the-box
    read :paginated_dashboard do
      pagination offset?: true, limit?: true, required?: false, default_limit: 25
      prepare aggregate(:total_low_stock, :count, :low_stock_products)
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
