defmodule AshPhoenixStarterWeb.DashboardLive do
  use AshPhoenixStarterWeb, :live_view
  use AshPhoenixStarterWeb.LiveTracking
  
  alias AshPhoenixStarter.GeoBoundaries
  alias AshPhoenixStarter.Settings.Manager
  # 1. UPDATED: Swapped tracking module reference out for your core dynamic Product resource
  alias AshPhoenixStarter.Merchants.Product

  on_mount {AshPhoenixStarterWeb.LiveUserAuth, :live_user_required}

  require Ash.Query
  alias Phx.Live.Favicon

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns[:current_user].team.domain
    total_users = Ash.count!(AshPhoenixStarter.Accounts.User, authorize?: false)
    total_teams = Ash.count!(AshPhoenixStarter.Accounts.Team, authorize?: false)

    supported_countries = [
      {"United States", "us"},
      {"France", "fr"},
      {"United Kingdom", "gb"},
      {"Canada", "ca"}
    ]

    active_country = Manager.get_tenant(tenant, :active_country) || "us"

    # 2. UPDATED: Call your new multitenant product engine code interface function
    live_metrics = 
      case Product.get_live_metrics_for_country(active_country, tenant: tenant) do
        {:ok, metrics} -> metrics
        _ -> %{}
      end

    # 3. UPDATED: Subscribe to your updated Product resource notifier stream channel
    if connected?(socket) do
      Phoenix.PubSub.subscribe(AshPhoenixStarter.PubSub, "products")
    end

    initial_map = 
      case GeoBoundaries.get_bounds(active_country) do
        {:ok, raw_geojson} ->
          {:ok, hydrated_geojson} = GeoBoundaries.inject_live_data({:ok, raw_geojson}, live_metrics)
          hydrated_geojson
        _ -> 
          %{"type" => "FeatureCollection", "features" => []}
      end

    active_teams =
      AshPhoenixStarter.Accounts.Team
      |> Ash.Query.filter(active == true)
      |> Ash.count!(authorize?: false)


merchants_stock =
  AshPhoenixStarter.Accounts.Merchant
  |> Ash.Query.load(low_stock_products: [:alert_level])
  |> Ash.read!(tenant: tenant, authorize?: false)
  |> Enum.map(fn merchant ->
    # Filter the loaded products to only display items flagged as :low or :critical
    alert_products =
      Enum.filter(merchant.low_stock_products, fn product ->
        product.alert_level in [:low, :critical]
      end)
      |> Enum.map(fn product ->
        %{
          name: product.name,
          remaining_stock: product.remaining_stock,
          # Convert atom state (:critical -> "Critical") for your layout table
          alert_level: product.alert_level |> Atom.to_string() |> String.capitalize()
        }
      end)

    %{
      name: merchant.name,
      products: alert_products
    }
  end)
  # Clean up the output list by omitting merchants who currently have 0 alerts
  |> Enum.reject(fn merchant -> Enum.empty?(merchant.products) end)


    socket =
      socket
      |> assign(:page_name, "Dashboard")
      |> assign(:total_users, total_users)
      |> assign(:active_users, Enum.count(list_online_users()))
      |> assign(:total_teams, total_teams)
      |> assign(:active_teams, active_teams)
      |> assign(:transactions_today, "\$72,000")
      |> assign(:transactions_processed, "500")
      |> assign(:map_data, initial_map)
      |> assign(:active_country, active_country)
      |> assign(:currency, get_currency_atom(active_country))
      |> assign(:merchants_stock, merchants_stock)
      |> assign(:supported_countries, supported_countries)
      |> Favicon.set_dynamic("favicon-32", "subfolder", "dashboard")
      |> Favicon.set_dynamic("favicon-16", "subfolder", "dashboard")

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    if AshPhoenixStarterWeb.Helpers.is_super_user?(assigns.current_user) do
      super_user(assigns)
    else
      non_super_user(assigns)
    end
  end

  def non_super_user(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} uri={@uri}></Layouts.app>
    """
  end

  def super_user(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} uri={@uri}>
      <h1 class="text-3xl font-bold mb-6">Today's Overview</h1>
      
      <!-- Stats Section -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-6">
        <div class="bg-base-100 border border-lg border-primary rounded-box p-6">
          <div class="stat-title text-lg">Total Users</div>
          <div class="stat-value">{@total_users}</div>
          <div class="stat-desc">Active Users</div>
          <div class="text-xs">{@active_users}</div>
        </div>

        <div class="bg-primary text-primary-content rounded-box p-6">
          <div class="stat-title text-lg text-base-200">Total Teams</div>
          <div class="stat-value">{@total_teams}</div>
          <div class="stat-desc text-base-100">Active Tenants</div>
          <div class="text-xs">{@active_teams}</div>
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

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
        <!-- Left Column: Controls & Map Graphic -->
        <div class="space-y-4">
          <AshPhoenixStarterWeb.Map.country_selector 
            selected={@active_country} 
            supported_countries={@supported_countries} 
          />
          
          <div class="card border border-primary bg-base-100 shadow-sm rounded-xl">
            <div class="card-body p-5">
              <h2 class="card-title text-lg font-bold mb-3 text-gray-800">Merchant Locations Map</h2>
              <AshPhoenixStarterWeb.Map.map initial_geojson={@map_data} height="500px" />
            </div>
          </div>
        </div>
        
        <!-- Right Column: Low Stock Management Panel -->
        <div class="card bg-base-100 h-full">
          <AshPhoenixStarterWeb.Stock.low merchants={@merchants_stock} />
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("select_country", %{"country_code" => country_code}, socket) do
    tenant = socket.assigns[:current_user].team.domain

    {:ok, live_metrics} = Product.get_live_metrics_for_country(country_code, tenant: tenant)
    
    case GeoBoundaries.get_bounds(country_code) do
      {:ok, raw_geojson} ->
        {:ok, fresh_map} = GeoBoundaries.inject_live_data({:ok, raw_geojson}, live_metrics)
        
        socket = 
          socket
          |> assign(map_data: fresh_map, active_country: country_code)
          |> push_event("render_new_layer", %{geojson: fresh_map})

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Map layout file not found.")}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "products", event: "updated", payload: %{data: product}}, socket) do
    tenant = socket.assigns[:current_user].team.domain
    
    # Pre-load the merchant onto the notification payload to check its territory coordinates
    product = Ash.load!(product, [:merchant], tenant: tenant)
    
    if product.merchant && String.downcase(product.merchant.country_code) == String.downcase(socket.assigns.active_country) do
      # Pull recalculations specifically for this updated region
      {:ok, region_metric} = Product.get_metrics_for_region(socket.assigns.active_country, product.merchant.region_name, tenant: tenant)
      updated_count = Map.get(region_metric, product.merchant.region_name, 0)

      # Stream the atomic update directly to your frontend hook
      {:noreply, push_event(socket, "update_stock", %{"province_name" => product.merchant.region_name, "new_stock" => updated_count})}
    else
      {:noreply, socket}
    end
  end
end
