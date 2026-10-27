defmodule AshPhoenixStarter.Core.RegionLocation do
  use Ash.Resource,
      domain: AshPhoenixStarter.Core,
      data_layer: AshPostgres.DataLayer

  postgres do
    table "region_locations"
    repo AshPhoenixStarter.Repo
  end

  identities do
    identity :unique_code_per_type_in_region, [:type, :value, :region_id],
             message: "This location mapping code is already registered to this region tier."
  end

  attributes do
    uuid_primary_key :id, writable?: false

    attribute :type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:zip_code, :postal_code, :area_code]
    end

    attribute :value, :string do
      allow_nil? false
      public? true # e.g., "85719", "M5V 2T6", or "520"
      constraints min_length: 2, max_length: 20
    end

    attribute :latitude, :float do
      allow_nil? true
      public? true
      constraints min: -90.0, max: 90.0
    end

    attribute :longitude, :float do
      allow_nil? true
      public? true
      constraints min: -180.0, max: 180.0
    end

    attribute :cached_timezone, :string do
      allow_nil? true
      public? true
      constraints match: ~r/^[A-Za-z0-9_\-+]+\/[A-Za-z0-9_\-+]+$/
    end
  end

  relationships do
    belongs_to :region, AshPhoenixStarter.Core.Region do
      attribute_type :uuid
      allow_nil? false
      public? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:type, :value, :region_id]

      validate &validate_postal_format_by_country/2, where: [attribute_equals(:type, :postal_code)]
    end
  end

  defp validate_postal_format_by_country(changeset, _opts) do
    region_id = Ash.Changeset.get_attribute(changeset, :region_id)
    value = Ash.Changeset.get_attribute(changeset, :value)

    case fetch_effective_country(region_id) do
      {:ok, country_string} ->
        country_atom = country_string |> String.downcase() |> String.to_atom()

        with {:ok, territory_info} <- Cldr.Config.territory_info(country_atom),
             postal_regex_string when not is_nil(postal_regex_string) <- Map.get(territory_info, :postal_code) do

          compiled_regex = Regex.compile!("^(" <> postal_regex_string <> ")$")

          if String.match?(value, compiled_regex) do
            :ok
          else
            {:error, Ash.Error.Changes.InvalidAttribute.exception(
              attribute: :value,
              message: "Postal code '#{value}' does not match the valid structure for country #{country_string}."
            )}
          end
        else
          _ -> :ok
        end

      :error ->
        :ok
    end
  end

  defp fetch_effective_country(nil), do: :error
  defp fetch_effective_country(region_id) do
    case Ash.get(AshPhoenixStarter.Core.Region, region_id) do
      {:ok, %{country_code: country}} when not is_nil(country) ->
        {:ok, country}

      {:ok, %{parent_id: parent_id}} when not is_nil(parent_id) ->
        fetch_effective_country(parent_id)

      _ ->
        :error
    end
  end

  calculations do
    calculate :resolved_timezone, :string, {AshPhoenixStarter.Core.Calculations.ResolveTimezone, []} do
      public? true
    end
  end
end