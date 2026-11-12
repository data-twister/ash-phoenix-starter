defmodule AshPhoenixStarterWeb.DashboardLive do
  use AshPhoenixStarterWeb, :live_view
  use AshPhoenixStarterWeb.LiveTracking

  alias AshPhoenixStarter.Accounts.{Merchant, Vendor}
  alias AshPhoenixStarter.Core.Product
  alias AshPhoenixStarter.GeoBoundaries
  alias AshPhoenixStarter.Settings.Manager

  on_mount {AshPhoenixStarterWeb.LiveUserAuth, :live_user_required}

  require Ash.Query
  alias Phx.Live.Favicon

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]
    tenant = current_user.organization.domain
    is_super? = AshPhoenixStarterWeb.Helpers.is_super_user?(current_user)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(AshPhoenixStarter.PubSub, "products:#{tenant}")
    end

    supported_countries = [
      {"United States", "us"},
      {"France", "fr"},
      {"United Kingdom", "gb"},
      {"Canada", "ca"}
    ]

    active_country = Manager.get_tenant(tenant, :active_country) || "us"

    # Tenant-scoped supply chain counts
    total_vendors = Ash.count!(Vendor, tenant: tenant, actor: current_user)
    total_merchants = Ash.count!(Merchant, tenant: tenant, actor: current_user)
    total_products = Ash.count!(Product, tenant: tenant, actor: current_user)

    # Tenant-scoped regional metrics for the active country
    live_metrics =
      case Product.get_live_metrics_for_country(active_country, tenant: tenant, actor: current_user) do
        {:ok, metrics} -> metrics
        _ -> %{}
      end

    sorted_metrics = Enum.sort_by(live_metrics, fn {_region, qty} -> qty end, :desc)
    total_stock = Enum.reduce(live_metrics, 0, fn {_region, qty}, acc -> acc + qty end)

    initial_map =
      case GeoBoundaries.get_bounds(active_country) do
        {:ok, raw_geojson} ->
          {:ok, hydrated_geojson} =
            GeoBoundaries.inject_live_data({:ok, raw_geojson}, live_metrics)

          hydrated_geojson

        _ ->
          %{"type" => "FeatureCollection", "features" => []}
      end

    # Only run global cross-tenant queries if the user is a super user
    {total_users, total_organizations, active_organizations, active_users} =
      if is_super? do
        active_orgs =
          AshPhoenixStarter.Accounts.Organization
          |> Ash.Query.filter(active == true)
          |> Ash.count!(authorize?: false)

        {
          Ash.count!(AshPhoenixStarter.Accounts.User, authorize?: false),
          Ash.count!(AshPhoenixStarter.Accounts.Organization, authorize?: false),
          active_orgs,
          Enum.count(list_online_users())
        }
      else
        {0, 0, 0, 0}
      end

    socket =
      socket
      |> assign(:page_name, "Dashboard")
      |> assign(:is_super_user, is_super?)
      |> assign(:tenant_domain, tenant)
      |> assign(:total_users, total_users)
      |> assign(:active_users, active_users)
      |> assign(:total_organizations, total_organizations)
      |> assign(:active_organizations, active_organizations)
      |> assign(:total_vendors, total_vendors)
      |> assign(:total_merchants, total_merchants)
      |> assign(:total_products, total_products)
      |> assign(:transactions_today, "\$72,000")
      |> assign(:transactions_processed, "500")
      |> assign(:map_data, initial_map)
      |> assign(:map_pins, load_map_pins(tenant, current_user, active_country))
      |> assign(:active_country, active_country)
      |> assign(:currency, get_currency_atom(active_country))
      |> assign(:regional_metrics, sorted_metrics)
      |> assign(:total_stock, total_stock)
      |> assign(:merchants_stock, load_merchants_stock(tenant, current_user))
      |> assign(:supported_countries, supported_countries)

    Favicon.set_dynamic("favicon-32", "subfolder", "dashboard")
    Favicon.set_dynamic("favicon-16", "subfolder", "dashboard")

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    if assigns.is_super_user do
      super_user(assigns)
    else
      non_super_user(assigns)
    end
  end

  # Keep your `def non_super_user(assigns)` and `def super_user(assigns)` templates here,
  # making sure both call:
  # <AshPhoenixStarterWeb.Map.map initial_geojson={@map_data} pins={@map_pins} height="500px" />

  @impl true
  def handle_event("select_country", %{"country_code" => country_code}, socket) do
    current_user = socket.assigns[:current_user]
    tenant = current_user.organization.domain

    {:ok, live_metrics} =
      Product.get_live_metrics_for_country(country_code, tenant: tenant, actor: current_user)

    sorted_metrics = Enum.sort_by(live_metrics, fn {_region, qty} -> qty end, :desc)
    total_stock = Enum.reduce(live_metrics, 0, fn {_region, qty}, acc -> acc + qty end)
    pins = load_map_pins(tenant, current_user, country_code)

    case GeoBoundaries.get_bounds(country_code) do
      {:ok, raw_geojson} ->
        {:ok, fresh_map} = GeoBoundaries.inject_live_data({:ok, raw_geojson}, live_metrics)

        socket =
          socket
          |> assign(
            map_data: fresh_map,
            map_pins: pins,
            active_country: country_code,
            regional_metrics: sorted_metrics,
            total_stock: total_stock
          )
          |> push_event("render_new_layer", %{geojson: fresh_map})
          |> push_event("update_pins", %{pins: pins})

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Map layout file not found.")}
    end
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "products:" <> broadcast_tenant,
          event: "updated",
          payload: %{data: product}
        },
        socket
      ) do
    current_user = socket.assigns[:current_user]
    tenant = current_user.organization.domain

    if broadcast_tenant == tenant do
      {:ok, live_metrics} =
        Product.get_live_metrics_for_country(socket.assigns.active_country,
          tenant: tenant,
          actor: current_user
        )

      sorted_metrics = Enum.sort_by(live_metrics, fn {_region, qty} -> qty end, :desc)
      total_stock = Enum.reduce(live_metrics, 0, fn {_region, qty}, acc -> acc + qty end)

      socket =
        socket
        |> assign(:merchants_stock, load_merchants_stock(tenant, current_user))
        |> assign(:total_products, Ash.count!(Product, tenant: tenant, actor: current_user))
        |> assign(:regional_metrics, sorted_metrics)
        |> assign(:total_stock, total_stock)

      merchant =
        case product.merchant_id do
          nil -> nil
          merchant_id -> Ash.get!(Merchant, merchant_id, tenant: tenant, actor: current_user)
        end

      if merchant &&
           String.downcase(merchant.country_code) ==
             String.downcase(socket.assigns.active_country) do
        {:ok, region_metric} =
          Product.get_metrics_for_region(
            socket.assigns.active_country,
            merchant.region_name,
            tenant: tenant,
            actor: current_user
          )

        updated_count = Map.get(region_metric, merchant.region_name, 0)

        {:noreply,
         push_event(socket, "update_stock", %{
           "province_name" => merchant.region_name,
           "new_stock" => updated_count
         })}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # ===========================================================================
  # PRIVATE HELPERS
  # ===========================================================================

  defp load_merchants_stock(tenant, current_user) do
    Merchant
    |> Ash.Query.load(low_stock_products: [:alert_level])
    |> Ash.read!(tenant: tenant, actor: current_user)
    |> Enum.map(fn merchant ->
      alert_products =
        merchant.low_stock_products
        |> Enum.filter(fn product -> product.alert_level in [:low, :critical] end)
        |> Enum.map(fn product ->
          %{
            name: product.name,
            remaining_stock: product.remaining_stock,
            alert_level: product.alert_level |> Atom.to_string() |> String.capitalize()
          }
        end)

      %{
        name: merchant.name,
        products: alert_products
      }
    end)
    |> Enum.reject(fn merchant -> Enum.empty?(merchant.products) end)
  end

  defp load_map_pins(tenant, current_user, country_code) do
    target_country = String.downcase(country_code)

    vendor_pins =
      Vendor
      |> Ash.Query.load(:region_locations)
      |> Ash.read!(tenant: tenant, actor: current_user)
      |> Enum.filter(&(String.downcase(&1.country_code) == target_country))
      |> extract_pins(:vendor)

    merchant_pins =
      Merchant
      |> Ash.Query.load(:region_locations)
      |> Ash.read!(tenant: tenant, actor: current_user)
      |> Enum.filter(&(String.downcase(&1.country_code) == target_country))
      |> extract_pins(:merchant)

    (vendor_pins ++ merchant_pins)
    |> apply_overlap_offsets()
  end

  defp extract_pins(records, type) do
    Enum.flat_map(records, fn record ->
      record.region_locations
      |> Enum.filter(&(not is_nil(&1.latitude) and not is_nil(&1.longitude)))
      |> Enum.map(fn loc ->
        %{
          id: record.id,
          type: Atom.to_string(type),
          name: record.name,
          region_name: record.region_name,
          code: loc.value,
          lat: loc.latitude,
          lng: loc.longitude
        }
      end)
    end)
  end


  defp apply_overlap_offsets(pins) do
    pins
    |> Enum.group_by(fn pin -> {Float.round(pin.lat, 5), Float.round(pin.lng, 5)} end)
    |> Enum.flat_map(fn
      {_coords, [single_pin]} ->
        [single_pin]

      {_coords, overlapping_pins} ->
        count = length(overlapping_pins)
        radius = 0.008

        overlapping_pins
        |> Enum.with_index()
        |> Enum.map(fn {pin, idx} ->
          angle = 2 * :math.pi() * idx / count

          %{
            pin
            | lat: pin.lat + radius * :math.sin(angle),
              lng: pin.lng + radius * :math.cos(angle)
}
end)
end)
end
end
# If you'd like to add **clickable `/products?vendor_id=...` or `/products?merchant_id=...` links inside the map pin popups**, let me know and I can add `id` to `extract_pins/2` and the popup HTML!

  # ===========================================================================
  # TENANT-SCOPED VIEW (NON-SUPER USER)
  # ===========================================================================
  def non_super_user(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} uri={@uri}>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
        <div>
          <h1 class="text-3xl font-bold">Domain Overview</h1>
          <p class="text-sm text-base-content/70 mt-1">
            Scoped to organization domain: <span class="font-mono font-semibold">{@tenant_domain}</span>
          </p>
        </div>

        <div class="flex flex-wrap gap-2">
          <.link navigate={~p"/vendors"} class="btn btn-sm btn-outline">
            Vendors
          </.link>
          <.link navigate={~p"/merchants"} class="btn btn-sm btn-outline">
            Merchants
          </.link>
          <.link navigate={~p"/products"} class="btn btn-sm btn-primary">
            Products
          </.link>
        </div>
      </div>

      <!-- Tenant-Scoped Summary Cards -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-6">
        <.link
          navigate={~p"/vendors"}
          class="bg-base-100 border border-base-300 hover:border-primary transition rounded-box p-5"
        >
          <div class="stat-title text-sm">Domain Vendors</div>
          <div class="stat-value text-2xl">{@total_vendors}</div>
          <div class="stat-desc mt-1 text-primary underline">Manage vendors &rarr;</div>
        </.link>

        <.link
          navigate={~p"/merchants"}
          class="bg-base-100 border border-base-300 hover:border-primary transition rounded-box p-5"
        >
          <div class="stat-title text-sm">Domain Merchants</div>
          <div class="stat-value text-2xl">{@total_merchants}</div>
          <div class="stat-desc mt-1 text-primary underline">Manage merchants &rarr;</div>
        </.link>

        <.link
          navigate={~p"/products"}
          class="bg-base-100 border border-base-300 hover:border-primary transition rounded-box p-5"
        >
          <div class="stat-title text-sm">Domain Products</div>
          <div class="stat-value text-2xl">{@total_products}</div>
          <div class="stat-desc mt-1 text-primary underline">View catalog &rarr;</div>
        </.link>

        <div class="bg-primary text-primary-content rounded-box p-5">
          <div class="stat-title text-sm text-primary-content/80">
            Regional Stock ({String.upcase(@active_country)})
          </div>
          <div class="stat-value text-2xl">{@total_stock}</div>
          <div class="stat-desc text-primary-content/80 mt-1">
            Across {length(@regional_metrics)} active regions
          </div>
        </div>
      </div>

      <!-- Regional Breakdown & Map -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start mb-6">
        <div class="space-y-4">
                        <AshPhoenixStarterWeb.Map.map
                initial_geojson={@map_data}
                pins={@map_pins}
                height="420px"
              />

          <div class="card border border-primary bg-base-100 shadow-sm rounded-xl">
            <div class="card-body p-5">
              <h2 class="card-title text-lg font-bold mb-3">Regional Stock Map</h2>
              <AshPhoenixStarterWeb.Map.map initial_geojson={@map_data} height="420px" />
            </div>
          </div>
        </div>

        <div class="space-y-6">
          <!-- Stock by Region Progress List -->
          <div class="card border border-base-300 bg-base-100 shadow-sm rounded-xl">
            <div class="card-body p-5">
              <h2 class="card-title text-lg font-bold mb-3">
                Stock by Region ({String.upcase(@active_country)})
              </h2>

              <div :if={@regional_metrics == []} class="text-sm text-base-content/60 py-4">
                No regional stock recorded for this country in your domain yet.
              </div>

              <div class="space-y-4">
                <div :for={{region_name, qty} <- @regional_metrics}>
                  <div class="flex justify-between items-center text-sm mb-1">
                    <span class="font-semibold">{region_name}</span>
                    <span class="font-mono">{qty} units</span>
                  </div>
                  <div class="w-full bg-base-200 rounded-full h-2.5 overflow-hidden">
                    <% pct = if @total_stock > 0, do: Float.round(qty / @total_stock * 100, 1), else: 0 %>
                    <div class="bg-primary h-2.5 rounded-full" style={"width: #{pct}%"}></div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Domain Low-Stock Alerts -->
          <div class="card bg-base-100">
            <AshPhoenixStarterWeb.Stock.low merchants={@merchants_stock} />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

   # ===========================================================================
  # GLOBAL PLATFORM VIEW (SUPER USER)
  # ===========================================================================
  def super_user(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} uri={@uri}>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
        <h1 class="text-3xl font-bold">Today's Overview</h1>

        <div class="flex flex-wrap gap-2">
          <.link navigate={~p"/vendors"} class="btn btn-sm btn-outline">
            Manage Vendors
          </.link>
          <.link navigate={~p"/merchants"} class="btn btn-sm btn-outline">
            Manage Merchants
          </.link>
          <.link navigate={~p"/products"} class="btn btn-sm btn-primary">
            Manage Products
          </.link>
        </div>
      </div>

      <!-- Global Stats Section -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-6">
        <div class="bg-base-100 border border-lg border-primary rounded-box p-6">
          <div class="stat-title text-lg">Total Users</div>
          <div class="stat-value">{@total_users}</div>
          <div class="stat-desc">Active Users</div>
          <div class="text-xs">{@active_users}</div>
        </div>

        <div class="bg-primary text-primary-content rounded-box p-6">
          <div class="stat-title text-lg text-base-200">Total Organizations</div>
          <div class="stat-value">{@total_organizations}</div>
          <div class="stat-desc text-base-100">Active Tenants</div>
          <div class="text-xs">{@active_organizations}</div>
        </div>

        <div class="bg-base-300 text-primary-content border border-lg border-primary rounded-box p-6">
          <div class="stat-title text-lg">Revenue</div>
          <div class="stat-value">12,000</div>
          <div class="stat-desc">Next Harvest</div>
        </div>

        <div class="stat bg-base-100 border border-secondary rounded-box p-6">
          <div class="stat-title text-lg">Transactions Today</div>
          <div class="stat-value">{@transactions_today}</div>
          <div class="stat-desc">Number of transactions processed</div>
          <div class="text-xs">{@transactions_processed}</div>
        </div>
      </div>

      <!-- Supply Chain Directory Cards -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
        <.link
          navigate={~p"/vendors"}
          class="bg-base-100 border border-base-300 hover:border-primary transition rounded-box p-5 flex items-center justify-between"
        >
          <div>
            <div class="stat-title text-sm">Vendors</div>
            <div class="stat-value text-2xl">{@total_vendors}</div>
            <div class="stat-desc mt-1">View & manage supply partners</div>
          </div>
          <span class="text-sm font-medium text-primary underline">Open &rarr;</span>
        </.link>

        <.link
          navigate={~p"/merchants"}
          class="bg-base-100 border border-base-300 hover:border-primary transition rounded-box p-5 flex items-center justify-between"
        >
          <div>
            <div class="stat-title text-sm">Merchants</div>
            <div class="stat-value text-2xl">{@total_merchants}</div>
            <div class="stat-desc mt-1">View & manage regional storefronts</div>
          </div>
          <span class="text-sm font-medium text-primary underline">Open &rarr;</span>
        </.link>

        <.link
          navigate={~p"/products"}
          class="bg-base-100 border border-base-300 hover:border-primary transition rounded-box p-5 flex items-center justify-between"
        >
          <div>
            <div class="stat-title text-sm">Products</div>
            <div class="stat-value text-2xl">{@total_products}</div>
            <div class="stat-desc mt-1">Inspect stock & low-stock alerts</div>
          </div>
          <span class="text-sm font-medium text-primary underline">Open &rarr;</span>
        </.link>
      </div>

      <!-- Map & Low-Stock Management Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
        <div class="space-y-4">
          <AshPhoenixStarterWeb.Map.country_selector
            selected={@active_country}
            supported_countries={@supported_countries}
          />

          <div class="card border border-primary bg-base-100 shadow-sm rounded-xl">
            <div class="card-body p-5">
              <h2 class="card-title text-lg font-bold mb-3 text-gray-800">Merchant Locations Map</h2>
              <AshPhoenixStarterWeb.Map.map
                initial_geojson={@map_data}
                pins={@map_pins}
                height="500px"
              />
            </div>
          </div>
        </div>

        <div class="card bg-base-100 h-full">
          <AshPhoenixStarterWeb.Stock.low merchants={@merchants_stock} />
        </div>
      </div>
    </Layouts.app>
    """
  end


end