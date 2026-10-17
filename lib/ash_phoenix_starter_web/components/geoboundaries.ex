defmodule AshPhoenixStarter.GeoBoundaries do
  @moduledoc """
  A flexible boundary engine that sanitizes country codes and auto-detects 
  region property names inside arbitrary GeoJSON datasets.
  """

  # Common structural properties used globally in geographic files
  @name_keys ["name", "NAME", "NAME_1", "state_name", "state", "code", "iso_a2", "ISO_A2"]

  @doc """
  Safely sanitizes incoming country queries (e.g., "  Fr " -> "fr").
  Loads the matching JSON file from the priv/ directory.
  """
  def get_bounds(country_code) when is_binary(country_code) do
    # Normalize input (removes spacing mistakes, forces lowercase)
    clean_code = country_code |> String.trim() |> String.downcase()
    file_path = Application.app_dir(:ash_phoenix_starter, "priv/repo/geojson/#{clean_code}.json")

    case File.read(file_path) do
      {:ok, raw_json} -> Jason.decode(raw_json)
      {:error, :enoent} -> {:error, :not_found}
    end
  end

  @doc """
  Fuses your dynamic database metrics into the GeoJSON structure.
  It standardizes string checking by comparing lowercase, trimmed text values.
  """
  def inject_live_data({:ok, %{"type" => "FeatureCollection", "features" => features} = geojson}, live_data) do
    # Transform live_data keys to lowercase/trimmed text for foolproof mapping match checks
    normalized_live_data = 
      Map.new(live_data, fn {key, val} -> 
        {normalize_string(key), val} 
      end)

    hydrated_features = Enum.map(features, fn feature ->
      properties = feature["properties"] || %{}
      
      # 1. Look through priority keys to find whatever name string is inside this file
      raw_region_name = Enum.find_value(@name_keys, fn key -> properties[key] end)

      # 2. Match it up against your live data map
      stock_count = 
        if raw_region_name do
          Map.get(normalized_live_data, normalize_string(raw_region_name), 0)
        else
          0
        end

      # 3. Add consistent output keys ("name" and "density") for your Javascript layer
      updated_properties = 
        properties
        | Mesozoic.merge(%{
            "name" => raw_region_name || "Unknown Region",
            "density" => stock_count
          })

      Map.put(feature, "properties", updated_properties)
    end)

    {:ok, Map.put(geojson, "features", hydrated_features)}
  end

  def inject_live_data(error_tuple, _live_data), do: error_tuple

  # Shorthand helper to strip casing differences ("Texas " and "texas" match perfectly)
  defp normalize_string(nil), do: ""
  defp normalize_string(str) when is_binary(str) do
    str |> String.trim() |> String.downcase()
  end
end
