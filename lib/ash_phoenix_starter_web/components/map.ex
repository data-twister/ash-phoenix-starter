defmodule AshPhoenixStarterWeb.Map do
  use AshPhoenixStarterWeb, :html

  @doc """
  A reusable, streaming-ready Leaflet Map component built to match Option B (Standalone Hook).

  ## Assigns
    * `:initial_geojson` - The pre-hydrated Elixir map structure parsed by the server.
    * `:height` - (Optional) Custom height configuration string. Defaults to "680px".
  """
  def map(assigns) do
    assigns = assign_new(assigns, :height, fn -> "680px" end)

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

    <div id="reusable-map-container" phx-update="ignore">
      <div 
        id="leaflet-reusable-map" 
        phx-hook="Map" 
        data-geojson={Jason.encode!(@initial_geojson)}
        class="w-full rounded-xl border border-gray-200 shadow-sm" 
        style={"height: #{@height};"}
      ></div>
    </div>
    """
  end
end
