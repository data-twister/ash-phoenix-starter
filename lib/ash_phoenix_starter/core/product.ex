defmodule AshPhoenixStarter.Merchants.Product do
  use Ash.Resource,
    domain: AshPhoenixStarter.Core,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "products"
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
  end

  attributes do
    uuid_primary_key :id, writable?: false

    attribute :name, :string do
      allow_nil? false
      public? true
    end
    
    attribute :price, :integer do
      allow_nil? false
      public? true
    end

    attribute :remaining_stock, :integer do
      allow_nil? false
      default 0
      public? true
    end

    attribute :low_stock_threshold, :integer do
      allow_nil? false
      default 2000 
      public? true
    end

    attribute :critical_stock_threshold, :integer do
      allow_nil? false
      default 500 
      public? true
    end

    # Database-managed timestamps
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
    belongs_to :merchant, AshPhoenixStarter.Accounts.Merchant do
      attribute_type :uuid
      allow_nil? false
      public? true
    end
  end

  calculations do
    calculate :alert_level, :atom, expr(
      if(remaining_stock <= critical_stock_threshold, do: :critical, else: 
        if(remaining_stock <= low_stock_threshold, do: :low, else: :ok)
      )
    ) do
      public? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :remaining_stock, :price, :low_stock_threshold, :critical_stock_threshold, :merchant_id]
    end

    update :update do
      primary? true
      accept [:name, :remaining_stock, :price, :low_stock_threshold, :critical_stock_threshold, :merchant_id]
    end

    # =========================================================================
    # DYNAMIC REGIONAL MAP ACTIONS
    # =========================================================================

    action :get_metrics_for_region, :map do
      description "Retrieves aggregated product remaining_stock for a single region inside a country"

      argument :country_code, :string, allow_nil?: false
      argument :region_name, :string, allow_nil?: false

      run fn input, context ->
        requested_country = input.arguments.country_code |> String.trim() |> String.downcase()
        requested_region = input.arguments.region_name |> String.trim() |> String.downcase()

        case Ash.read(AshPhoenixStarter.Merchants.Product, load: [:merchant], tenant: context.tenant) do
          {:ok, products} ->
            total_qty = 
              products
              |> Enum.filter(fn product -> 
                merchant = product.merchant
                merchant && 
                  String.downcase(merchant.country_code) == requested_country &&
                  String.downcase(merchant.region_name) == requested_region
              end)
              |> Enum.reduce(0, fn product, acc -> product.remaining_stock + acc end)

            {:ok, %{input.arguments.region_name => total_qty}}

          {:error, error} ->
            {:error, error}
        end
      end
    end

    action :get_live_metrics_for_country, :map do
      description "Aggregates product remaining_stock for all regions belonging to a targeted country"

      argument :country_code, :string, allow_nil?: false

      run fn input, context ->
        requested_country = input.arguments.country_code |> String.trim() |> String.downcase()

        case Ash.read(AshPhoenixStarter.Merchants.Product, load: [:merchant], tenant: context.tenant) do
          {:ok, products} ->
            metrics_map = 
              products
              |> Enum.filter(fn product -> 
                product.merchant && String.downcase(product.merchant.country_code) == requested_country
              end)
              |> Enum.reduce(%{}, fn product, acc ->
                region = product.merchant.region_name
                Map.update(acc, region, product.remaining_stock, &(&1 + product.remaining_stock))
              end)

            {:ok, metrics_map}

          {:error, error} ->
            {:error, error}
        end
      end
    end

    action :get_all_live_metrics, :map do
      description "Aggregates and transforms all catalog remaining_stock entries across all regions and countries"
      
      run fn _input, context ->
        case Ash.read(AshPhoenixStarter.Merchants.Product, load: [:merchant], tenant: context.tenant) do
          {:ok, products} ->
            metrics_map = 
              products
              |> Enum.filter(& &1.merchant)
              |> Enum.reduce(%{}, fn product, acc ->
                region = product.merchant.region_name
                Map.update(acc, region, product.remaining_stock, &(&1 + product.remaining_stock))
              end)

            {:ok, metrics_map}

          {:error, error} ->
            {:error, error}
        end
      end
    end
  end

  code_interface do
    define :get_metrics_for_region, args: [:country_code, :region_name]
    define :get_live_metrics_for_country, args: [:country_code]
    define :get_all_live_metrics
  end

  pub_sub do
    module AshPhoenixStarterWeb.Endpoint
    prefix "products"
    publish :update, ["merchant", :merchant_id, "updated"], "updated"
  end
end
