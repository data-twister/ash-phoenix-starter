defmodule AshPhoenixStarter.Accounts.Vendor do
  use Ash.Resource,
      domain: AshPhoenixStarter.Accounts,
      data_layer: AshPostgres.DataLayer,
      authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "vendors"
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
      destination_attribute :vendor_id
      filter expr(remaining_stock <= low_stock_threshold)
    public? true
    end

    many_to_many :region_locations, AshPhoenixStarter.Accounts.RegionLocation do
      through AshPhoenixStarter.Accounts.VendorRegionLocation
      source_attribute_on_join_resource :vendor_id
      destination_attribute_on_join_resource :region_location_id
      join_relationship :vendor_region_locations
      public? true
    end    
  end

  # =====================================================================
  # 📐 Aggregates Definition Block
  # =====================================================================
  aggregates do
    count :total_low_stock, :low_stock_products do
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

      argument :region_location_ids, {:array, :uuid} do
        allow_nil? true
        public? true
      end

      change manage_relationship(:region_location_ids, :region_locations,
               type: :append_and_remove
             )
    end

    update :update do
      primary? true
      accept [:name, :country_code, :region_name, :user_id, :region_id]
      require_atomic? false

      argument :region_location_ids, {:array, :uuid} do
        allow_nil? true
        public? true
      end

      change manage_relationship(:region_location_ids, :region_locations,
               type: :append_and_remove
             )
    end

    # Custom paginated read action tailored for internal dashboard components
    read :paginated_dashboard do
      pagination offset?: true, required?: false, default_limit: 25
      prepare fn query, _ -> Ash.Query.load(query, :total_low_stock) end
    end
  end
  

  policies do
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    # Allow any authenticated user in the current tenant context to read records
    policy action_type(:read) do
      authorize_if actor_present()
    end

    # Allow authenticated users to create records where user_id matches their own ID
    policy action_type(:create) do
      authorize_if relating_to_actor(:user)
    end

    # Allow only the record's owner to update or destroy it
    policy action_type([:update, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end
end