defmodule AshPhoenixStarterWeb.Map do
  use AshPhoenixStarterWeb, :html

  @doc """
  Renders the global Leaflet CDN stylesheets and scripts required for the map hook.
  Call this inside the <head> of your layout.
  """
  def assets(assigns) do
    ~H"""
    <link
      rel="stylesheet"
      href="https://unpkg.com"
      integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY="
      crossorigin=""
    />
    <script
      src="https://unpkg.com"
      integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo="
      crossorigin=""
    >
    </script>
    """
  end

  @doc """
  A reusable dropdown menu for toggling map layers across dynamically provided country codes.

  ## Assigns
    * `:selected` - The active country code string (e.g. "us", "fr").
    * `:supported_countries` - A list of tuples containing `{"Display Name", "country_code"}`
  """
  def country_selector(assigns) do
    ~H"""
    <div class="mb-4 max-w-xs">
      <form phx-change="select_country" class="m-0">
        <label
          for="country-select"
          class="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-1.5"
        >
          Select Territory
        </label>
        <select
          id="country-select"
          name="country_code"
          class="block w-full rounded-lg border border-gray-300 bg-white py-2 px-3 text-sm shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 text-gray-900 font-medium"
        >
          <%= for {name, code} <- @supported_countries do %>
            <option value={code} selected={code == @selected}>{name}</option>
          <% end %>
        </select>
      </form>
    </div>
    """
  end

  @doc """
  A reusable, streaming-ready Leaflet Map component built to match Option B (Standalone Hook).

  ## Assigns
    * `:initial_geojson` - The pre-hydrated Elixir map structure parsed by the server.
    * `:height` - (Optional) Custom height configuration string. Defaults to "680px".
  """
  def map(assigns) do
    assigns = assign_new(assigns, :height, fn -> "680px" end)

    ~H"""
    <div id="reusable-map-container" phx-update="ignore">
      <div
        id="leaflet-reusable-map"
        phx-hook="Map"
        data-geojson={Jason.encode!(@initial_geojson)}
        class="w-full rounded-xl border border-gray-200 shadow-sm"
        style={"height: #{@height};"}
      >
      </div>
    </div>
    """
  end
end
