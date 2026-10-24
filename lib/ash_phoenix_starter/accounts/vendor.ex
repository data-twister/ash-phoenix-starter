defmodule AshPhoenixStarter.Accounts.Vendor do
  use Ash.Resource,
    domain: AshPhoenixStarter.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "vendors"
    repo AshPhoenixStarter.Repo

    # Ensure uniqueness constraints are trapped cleanly at the database layer
    # safely isolated inside each distinct multi-tenant context boundary.
    identity :unique_vendor_name_per_tenant, [:name], message: "A vendor with this name already exists."
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
    # Efficient expression calculation compiled straight down into the running SQL queries
    calculate :low_stock_count, :integer, expr(count(low_stock_products)) do
      public? true
    end

    # Utility flag evaluating geographical alignment logic
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
      
      # Clean uppercase coercion for country tracking properties
      change into_context(:country_code, &String.upcase/1)
    end

    update :update do
      primary? true
      accept [:name, :country_code, :region_name, :user_id, :region_id]
      
      change into_context(:country_code, &String.upcase/1)
    end

    # Custom paginated read action tailored for internal dashboard components
    read :paginated_dashboard do
      pagination offset?: true, limit?: true, required?: false, default_limit: 25
      prepare aggregate(:total_low_stock, :count, :low_stock_products)
    end
  end
end
