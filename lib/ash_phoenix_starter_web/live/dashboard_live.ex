defmodule AshPhoenixStarterWeb.DashboardLive do
  use AshPhoenixStarterWeb, :live_view
  use AshPhoenixStarterWeb.LiveTracking
  alias AshPhoenixStarter.GeoBoundaries
  alias AshPhoenixStarter.Settings.Manager
  alias AshPhoenixStarter.Accounts.MerchantStock 

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

    {status, live_metrics} = AshPhoenixStarter.Accounts.MerchantStock.get_live_metrics_for_country(active_country)
    
    live_metrics = case status do
      :ok -> live_metrics
      _-> %{}
    end

    if connected?(socket) do
      #  merchant_id = socket.assigns.current_merchant.id
      # Phoenix.PubSub.subscribe(AshPhoenixStarterWeb.PubSub, "products:merchant:#{merchant_id}:updated")
      Phoenix.PubSub.subscribe(AshPhoenixStarter.PubSub, "merchant_stock:update")
    end

     {status, initial_map} = GeoBoundaries.get_bounds(active_country) |> GeoBoundaries.inject_live_data(live_metrics)

      initial_map = case status do
      :ok -> initial_map
      _-> %{}
    end

    active_teams =
      AshPhoenixStarter.Accounts.Team
      |> Ash.Query.filter(active == true)
      |> Ash.count!(authorize?: false)

    merchants_stock = [
    %{
      name: "Merchant A",
      products: [
        %{name: "Product X", remaining_stock: 7200, alert_level: "Low"}
      ]
    },
    %{
      name: "Merchant B",
      products: [
        %{name: "Product Y", remaining_stock: 1200, alert_level: "Critical"},
        %{name: "Product Z", remaining_stock: 3200, alert_level: "Low"}
      ]
    }
  ]
      

    socket =
      socket
      |> assign(:page_name, "Dashboard")
      |> assign(:total_users, total_users)
      |> assign(:active_users, Enum.count(list_online_users()))
      |> assign(:total_teams, total_teams)
      |> assign(:active_teams, active_teams)
      |> assign(:transactions_today, "$72,000")
      |> assign(:transactions_processed, "500")
      |> assign(:map_data, initial_map)
      |> assign(:active_country active_country)
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
          <div class="stat-figure"></div>
          <div class="stat-title text-lg">Total Users</div>
          <div class="stat-value">{@total_users}</div>
          <div class="stat-desc">Active Users</div>
          <div class="text-size-xs">{@active_users}</div>
        </div>

        <div class=" bg-base-100 bg-primary text-primary-content rounded-box p-6">
          <div class="stat-figure"></div>
          <div class="stat-title text-lg text-base-200">Total Teams</div>
          <div class="stat-value">{@total_teams}</div>
          <div class="stat-desc text-base-100">Active Tenants</div>
          <div class="text-size-xs">{@active_teams}</div>
        </div>

        <div class="bg-base-300 text-primary-content border border-lg border-primary rounded-box p-6">
          <div class="stat-title  text-lg">Revenue</div>
          <div class="stat-value ">12,000</div>
          <div class="stat-desc ">Next Harvest</div>
        </div>

        <div class="stat bg-base-100 border border-secondary rounded-box p-6">
          <div class="stat-figure "></div>
          <div class="stat-title text-lg">Transactions Today</div>
          <div class="stat-value">{@transactions_today}</div>
          <div class="stat-desc">Number of transactions processed</div>
          <div class="text-size-xs">{@transactions_processed}</div>
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
  def handle_event("switch_country", %{"code" => country_code}, socket) do
    {:ok, fresh_map} = GeoBoundaries.get_bounds(country_code) |> GeoBoundaries.inject_live_data(%{})
    
    socket = 
      socket
      |> assign(map_data: fresh_map, active_country: country_code)
      |> push_event("render_new_layer", %{geojson: fresh_map})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:stock_update, %{region: region_name, count: updated_count}}, socket) do
    # STREAMING ENGINE: Receives live events out-of-band and flashes color alterations onto the map layout canvas

    {:noreply, push_event(socket, "update_stock", %{province_name: region_name, new_stock: updated_count})}
  end

end
