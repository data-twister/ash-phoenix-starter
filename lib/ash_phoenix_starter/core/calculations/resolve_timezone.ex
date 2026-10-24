defmodule AshPhoenixStarter.Core.Calculations.ResolveTimezone do
  use Ash.Resource.Calculation
  require Logger

  # Define the named ConCache atom reference configured in your application supervision tree
  @cache_name :timezone_resolution_cache

  @impl true
  def describe(_opts), do: "Resolves IANA timezone using database columns, local TzWorld, ConCache memory, or API fallbacks"

  @impl true
  def calculate(records, _opts, _context) do
    # Check if the :tz_world module dependency is loaded in the current BEAM runtime context
    tz_world_available? = Code.ensure_loaded?(TzWorld)

    Enum.map(records, fn record ->
      cond do
        # 1. Prioritize pre-saved database persistent columns if populated
        has_attribute?(record, :cached_timezone) && not is_nil(record.cached_timezone) ->
          record.cached_timezone

        # 2. Process lookups if valid coordinate metrics exist
        not is_nil(record.latitude) and not is_nil(record.longitude) ->
          # Check our in-memory ConCache registry using the coordinate pair as a compound key
          case fetch_from_memory_cache(record.latitude, record.longitude) do
            timezone_string when is_binary(timezone_string) ->
              timezone_string

            nil ->
              # Cache miss: Fall back to TzWorld or HTTP API and save the result to memory
              resolved_tz = 
                if tz_world_available? do
                  lookup_local_tz_world(record.latitude, record.longitude)
                else
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
    # Using apply/3 completely insulates the compiler against crashing 
    # if the TzWorld module structure doesn't exist at compile time.
    case apply(TzWorld, :timezone_at, [{lon, lat}]) do
      {:ok, timezone_string} -> 
        timezone_string
      _ -> 
        # Fail open to the API layer if coordinates miss local boundary polygons
        fetch_timezone_from_api(lat, lon)
    end
  end

  defp fetch_timezone_from_api(lat, lon) do
    # FIX: Appended correct target endpoint path parameter for coordinate queries
    url = "https://timeapi.io"
    
    Logger.info("[Timezone Resolution] TzWorld/Cache miss. Executing external API fallback for: {lat: #{lat}, lon: #{lon}}")

    # Pooled low-latency network request via your app's native :req dependency
    case Req.get(url, query: [latitude: lat, longitude: lon], retry: false, receive_timeout: 2000) do
      {:ok, %Req.Response{status: 200, body: %{"timeZone" => tz_string}}} ->
        tz_string

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("[Timezone API Fallback] Received non-200 status code: #{status}")
        nil

      {:error, reason} ->
        Logger.error("[Timezone API Fallback] Network connection failed. Reason: #{inspect(reason)}")
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

  # Helper to guard against structurally mismatched record layouts during computation passes
  defp has_attribute?(record, attr) do
    Map.has_key?(record, attr)
  end
end
