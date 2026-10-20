# lib/ash_phoenix_starter/accounts/resources/merchant_stock.ex
defmodule AshPhoenixStarter.Accounts.MerchantStock do
  use Ash.Resource,
    domain: AshPhoenixStarter.Accounts,
    data_layer: Ash.DataLayer.Postgres,
    notifiers: [Ash.Notifier.PubSub] 

  attributes do
    uuid_primary_key :id
    
    attribute :country_code, :string, allow_nil?: false 
    attribute :region_name, :string, allow_nil?: false # e.g., "Texas", "Brittany"
    attribute :qty, :integer, allow_nil?: false, default: 0
    
    timestamps()
  end

  pub_sub do
    module AshPhoenixStarterWeb.Endpoint 
    prefix "merchant_stock"
    publish :update, "update"
  end

  actions do
    action :get_metrics_for_region, :map do
      description "Retrieves stock metrics for a single region inside a specific country"

      argument :country_code, :string, allow_nil?: false
      argument :region_name, :string, allow_nil?: false

      run fn input, _context ->
        requested_country = input.arguments.country_code |> String.trim() |> String.downcase()
        requested_region = input.arguments.region_name |> String.trim() |> String.downcase()

        query = 
          AshPhoenixStarter.Accounts.MerchantStock
          |> Ash.Query.filter(
            string_downcase(country_code) == ^requested_country and
            string_downcase(region_name) == ^requested_region
          )

        case Ash.read(query) do
          {:ok, records} ->
            total_qty = Enum.reduce(records, 0, fn record, acc -> record.qty + acc end)
            {:ok, %{input.arguments.region_name => total_qty}}

          {:error, error} ->
            {:error, error}
        end
      end
    end

    action :get_live_metrics_for_country, :map do
      description "Aggregates metrics for all states/provinces belonging to a targeted country"

      argument :country_code, :string do
        allow_nil? false
      end

      run fn input, _context ->
        requested_country = input.arguments.country_code |> String.trim() |> String.downcase()

        query =
          AshPhoenixStarter.Accounts.MerchantStock
          |> Ash.Query.filter(string_downcase(country_code) == ^requested_country)

        case Ash.read(query) do
          {:ok, records} ->
            metrics_map = 
              Enum.reduce(records, %{}, fn record, acc ->
                Map.update(acc, record.region_name, record.qty, &(&1 + record.qty))
              end)

            {:ok, metrics_map}

          {:error, error} ->
            {:error, error}
        end
      end
    end

    action :get_all_live_metrics, :map do
      description "Aggregates and transforms all database entries across all countries into a clean metrics layout payload."
      
      run fn _input, _context ->
        case Ash.read(AshPhoenixStarter.Accounts.MerchantStock) do
          {:ok, records} ->
            metrics_map = 
              Enum.reduce(records, %{}, fn record, acc ->
                Map.update(acc, record.region_name, record.qty, &(&1 + record.qty))
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
end
