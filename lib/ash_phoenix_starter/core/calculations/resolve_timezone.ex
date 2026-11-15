defmodule AshPhoenixStarter.Core.Calculations.ResolveTimezone do
  @moduledoc """
  Ash calculation that resolves an IANA timezone string (e.g. `"America/Phoenix"`)
  for a record using a multi-tier lookup strategy:

  1. Pre-saved `:cached_timezone` column on the record (if present and non-nil)
  2. In-memory Nebulex cache (`AshPhoenixStarter.Cache.TimezoneResolution`)
  3. Local offline NIF/ETS lookup via `TzWorld` or `Geotz` (if installed)
  4. External HTTP fallback via `timeapi.io`
  """

  use Ash.Resource.Calculation
  require Logger

  alias AshPhoenixStarter.Cache.TimezoneResolution

  @timeapi_url "https://timeapi.io"

  @impl true
  def describe(_opts) do
    "Resolves IANA timezone using database columns, Nebulex cache, TzWorld, Geotz, or API fallbacks"
  end

  @impl true
  def calculate(records, _opts, _context) do
    engines = %{
      tz_world?: Code.ensure_loaded?(TzWorld),
      geotz?: Code.ensure_loaded?(Geotz)
    }

    Enum.map(records, &resolve_record(&1, engines))
  end

  # ============================================================================
  # PRIVATE RESOLUTION PIPELINE
  # ============================================================================

  defp resolve_record(%{cached_timezone: tz}, _engines) when is_binary(tz) and tz != "", do: tz

  defp resolve_record(%{latitude: lat, longitude: lon}, engines)
       when not is_nil(lat) and not is_nil(lon) do
    cache_key = normalize_coords(lat, lon)

    TimezoneResolution.fetch(cache_key, fn ->
      resolve_from_engines(lat, lon, engines)
    end)
  end

  defp resolve_record(_record, _engines), do: nil

  defp resolve_from_engines(lat, lon, engines) do
    with nil <- maybe_lookup_tz_world(lat, lon, engines.tz_world?),
         nil <- maybe_lookup_geotz(lat, lon, engines.geotz?) do
      fetch_timezone_from_api(lat, lon)
    end
  end

  defp maybe_lookup_tz_world(_lat, _lon, false), do: nil

  defp maybe_lookup_tz_world(lat, lon, true) do
    case apply(TzWorld, :timezone_at, [{lon, lat}]) do
      {:ok, timezone_string} -> timezone_string
      _ -> nil
    end
  end

  defp maybe_lookup_geotz(_lat, _lon, false), do: nil

  defp maybe_lookup_geotz(lat, lon, true) do
    case apply(Geotz, :timezone_at, [{lat, lon}]) do
      {:ok, timezone_string} -> timezone_string
      _ -> nil
    end
  end

  defp fetch_timezone_from_api(lat, lon) do
    Logger.info(
      "[Timezone Resolution] Local engines missed/unavailable. Querying external API for {lat: #{lat}, lon: #{lon}}"
    )

    case Req.get(@timeapi_url,
        Keyword.merge(
          [query: [latitude: lat, longitude: lon], retry: false, receive_timeout: 2_000],
          req_options()
        )
      ) do
      {:ok, %Req.Response{status: 200, body: %{"timeZone" => tz_string}}} ->
        tz_string

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("[Timezone API Fallback] Received non-200 status code: #{status}")
        nil

      {:error, reason} ->
        Logger.error("[Timezone API Fallback] Network request failed: #{inspect(reason)}")
        nil
    end
  end

  # Round coordinates to 3 decimal places (~110m) to maximize cache hits
  defp normalize_coords(lat, lon) do
    {round_coord(lat), round_coord(lon)}
  end

  defp round_coord(%Decimal{} = val), do: val |> Decimal.to_float() |> Float.round(3)
  defp round_coord(val) when is_float(val), do: Float.round(val, 3)
  defp round_coord(val) when is_integer(val), do: val / 1.0

  defp req_options do
  Application.get_env(:ash_phoenix_starter, :timezone_req_options, [])
end

end
