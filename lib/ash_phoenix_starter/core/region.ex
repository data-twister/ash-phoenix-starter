defmodule AshPhoenixStarter.Core.Region do
  use Ash.Resource,
    domain: AshPhoenixStarter.Core,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "regions"
    repo AshPhoenixStarter.Repo

    # Enforce name uniqueness strictly within the same parent tier
    identity :unique_name_per_parent, [:name, :parent_id], 
      message: "A region with this name already exists in this tier."
  end

  multitenancy do
    strategy :context
  end

  preparations do
    prepare AshPhoenixStarter.Preparations.SetTenant
  end

  changes do
    change AshPhoenixStarter.Changes.SetTenant
    
    # Automatically manage UTC microsecond timestamps on lifecycle events
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
      public? true # e.g., "European Union", "United States", or "Pacific Northwest"
      constraints min_length: 2, max_length: 100
    end

    attribute :type, :atom do
      allow_nil? false
      public? true
      # Enforce explicit tier levels for structured filtering
      constraints one_of: [:global_zone, :country, :state_province, :municipal_hub]
      default :state_province
    end

    attribute :country_code, :string do
      allow_nil? true # Optional to support macro-economic zones (e.g. EU) or regional clusters
      public? true
      constraints max_length: 2, match: ~r/^[A-Z]{2}$/
    end

    attribute :currency_code, :string do
      allow_nil? true # Optional: can be inherited down the tree from a macro parent if left blank
      public? true
      constraints max_length: 3, match: ~r/^[A-Z]{3}$/
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
    # Self-reference: Every region can optionally roll up into a parent node
    belongs_to :parent, AshPhoenixStarter.Core.Region do
      attribute_type :uuid
      allow_nil? true
      public? true
    end

    # Self-reference: A region can house multiple child nodes
    has_many :sub_regions, AshPhoenixStarter.Core.Region do
      destination_attribute :parent_id
      public? true
    end

    # Polymorphic location codes mapping zip/postal/area values
    has_many :locations, AshPhoenixStarter.Core.RegionLocation do
      public? true
    end

    has_many :merchants, AshPhoenixStarter.Accounts.Merchant do
      public? true
    end
  end

  # =====================================================================
  # 🧮 Hierarchical & Inherited Calculations
  # =====================================================================
  calculations do
    # Real-time evaluation checking if the active node is a root-level zone
    calculate :root_level?, :boolean, expr(is_nil(parent_id)) do
      public? true
    end

    # Resolves currency by falling back to the parent region if the local node doesn't define one
    calculate :effective_currency, :string, expr(if is_nil(currency_code) do parent.currency_code else currency_code end) do
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
      accept [:name, :type, :country_code, :currency_code, :parent_id]
      
      change into_context(:country_code, &String.upcase/1)
      change into_context(:currency_code, &String.upcase/1)

      # Injected ex_cldr Validation Hooks
      validate &validate_cldr_country/2, where: [attribute_not_nil(:country_code)]
      validate &validate_cldr_currency/2, where: [attribute_not_nil(:currency_code)]
    end

    update :update do
      primary? true
      accept [:name, :type, :country_code, :currency_code, :parent_id]
      
      change into_context(:country_code, &String.upcase/1)
      change into_context(:currency_code, &String.upcase/1)

      validate &validate_cldr_country/2, where: [attribute_not_nil(:country_code)]
      validate &validate_cldr_currency/2, where: [attribute_not_nil(:currency_code)]
    end

    # Custom dynamic resolution route targeting location codes inside child records
    read :by_location_code do
      argument :code_value, :string, allow_nil?: false
      argument :code_type, :atom, allow_nil?: false

      filter expr(locations.value == arg(:code_value) and locations.type == arg(:code_type))
    end

    # Optimized tree lookup to quickly pull top-level entry configurations
    read :roots do
      filter expr(is_nil(parent_id))
    end
  end

  # =====================================================================
  # 🌐 ex_cldr Inline Validation Hooks
  # =====================================================================

  defp validate_cldr_country(changeset, _opts) do
    country = Ash.Changeset.get_attribute(changeset, :country_code)
    atom_country = country |> String.downcase() |> String.to_atom()

    case Cldr.Territory.known_territory?(atom_country) do
      true -> :ok
      false -> {:error, Ash.Error.Changes.InvalidAttribute.exception(
        attribute: :country_code,
        message: "'#{country}' is not a valid ISO 3166-1 country code verified by CLDR."
      )}
    end
  end

  defp validate_cldr_currency(changeset, _opts) do
    currency = Ash.Changeset.get_attribute(changeset, :currency_code)

    case Cldr.Currency.known_currency?(currency) do
      true -> :ok
      false -> {:error, Ash.Error.Changes.InvalidAttribute.exception(
        attribute: :currency_code,
        message: "'#{currency}' is not a valid ISO 4217 currency code verified by CLDR."
      )}
    end
  end

  # =====================================================================
  # 🛡️ Data Access Control Security Policies
  # =====================================================================
  policies do
    bypass is_admin() do
      authorize_all()
    end

    policy always() do
      authorize_on_land read: true
    end
  end
end
