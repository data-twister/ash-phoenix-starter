defmodule AshPhoenixStarter.Core.Calculations.ResolveTimezone do
  use Ash.Resource.Calculation
  require Logger

  # Define the named ConCache atom reference configured in your application supervision tree
  @cache_name :timezone_resolution_cache

  @impl true
  def describe(_opts),
    do:
      "Resolves IANA timezone using database columns, ConCache memory, TzWorld, Geotz, or API fallbacks"

  @impl true
  def calculate(records, _opts, _context) do
    # Check what engine dependencies are natively loaded into the active BEAM runtime
    tz_world_available? = Code.ensure_loaded?(TzWorld)
    geotz_available? = Code.ensure_loaded?(Geotz)

    Enum.map(records, fn record ->
      cond do
        # 1. Prioritize pre-saved database persistent columns if populated
        has_attribute?(record, :cached_timezone) && not is_nil(record.cached_timezone) ->
          record.cached_timezone

        # 2. Process lookups if valid coordinate metrics exist
        not is_nil(record.latitude) and not is_nil(record.longitude) ->
          case fetch_from_memory_cache(record.latitude, record.longitude) do
            timezone_string when is_binary(timezone_string) ->
              timezone_string

            nil ->
              # Cache miss: Execute resolution strategy loop cascade
              resolved_tz =
                cond do
                  tz_world_available? ->
                    lookup_local_tz_world(record.latitude, record.longitude)

                  geotz_available? ->
                    lookup_local_geotz(record.latitude, record.longitude)

                  true ->
                    fetch_timezone_from_api(record.latitude, record.longitude)
                end

              store_in_memory_cache(record.latitude, record.longitude, resolved_tz)
              resolved_tz
          end

        true ->
          nil
      end
    end)
  end

  # --- Internal Resolution Engine Drivers ---

  defp lookup_local_tz_world(lat, lon) do
    # apply/3 safely insulates the compiler from crashing if the module is removed from mix.exs
    case apply(TzWorld, :timezone_at, [{lon, lat}]) do
      {:ok, timezone_string} -> timezone_string
      _ -> fetch_timezone_from_api(lat, lon)
    end
  end

  defp lookup_local_geotz(lat, lon) do
    # Geotz natively expects a coordinate lookup parameter mapped as {latitude, longitude} or via its signature
    case apply(Geotz, :timezone_at, [{lat, lon}]) do
      {:ok, timezone_string} -> timezone_string
      _ -> fetch_timezone_from_api(lat, lon)
    end
  end

  defp fetch_timezone_from_api(lat, lon) do
    url = "https://timeapi.io"

    Logger.info(
      "[Timezone Resolution] Local engines missed/not found. Executing external API fallback for: {lat: #{lat}, lon: #{lon}}"
    )

    case Req.get(url, query: [latitude: lat, longitude: lon], retry: false, receive_timeout: 2000) do
      {:ok, %Req.Response{status: 200, body: %{"timeZone" => tz_string}}} ->
        tz_string

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("[Timezone API Fallback] Received non-200 status code: #{status}")
        nil

      {:error, reason} ->
        Logger.error(
          "[Timezone API Fallback] Network connection failed. Reason: #{inspect(reason)}"
        )

        nil
    end
  end

  # --- ConCache Memory Registry Store/Fetch Mechanics ---

  defp fetch_from_memory_cache(lat, lon) do
    if Code.ensure_loaded?(ConCache) and Process.whereis(@cache_name) do
      ConCache.get(@cache_name, {lat, lon})
    else
      nil
    end
  end

  defp store_in_memory_cache(_lat, _lon, nil), do: nil

  defp store_in_memory_cache(lat, lon, timezone_string) do
    if Code.ensure_loaded?(ConCache) and Process.whereis(@cache_name) do
      ConCache.put(@cache_name, {lat, lon}, timezone_string)
    end

    timezone_string
  end

  defp has_attribute?(record, attr) do
    Map.has_key?(record, attr)
  end
end
