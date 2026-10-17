defmodule AshPhoenixStarterWeb.DashboardLive do
  use AshPhoenixStarterWeb, :live_view
  use AshPhoenixStarterWeb.LiveTracking

  on_mount {AshPhoenixStarterWeb.LiveUserAuth, :live_user_required}

  require Ash.Query
  alias Phx.Live.Favicon

  @impl true
  def mount(_params, _session, socket) do

     if connected?(socket) do
      Phoenix.PubSub.subscribe(AshPhoenixStarter.PubSub, "notifications:alerts")
    end

    total_users = Ash.count!(AshPhoenixStarter.Accounts.User, authorize?: false)
    total_teams = Ash.count!(AshPhoenixStarter.Accounts.Team, authorize?: false)

    active_teams =
      AshPhoenixStarter.Accounts.Team
      |> Ash.Query.filter(active == true)
      |> Ash.count!(authorize?: false)

    socket =
      socket
      |> assign(:page_name, "Dashboard")
      |> assign(:total_users, total_users)
      |> assign(:total_teams, total_teams)
      |> assign(:active_teams, active_teams)
      |> assign(:active_users, Enum.count(list_online_users()))
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

        <div class=" bg-base-100 bg-primary-content text-primary border border-primary rounded-box p-6">
          <div class="stat-title text-primary text-lg">Revenue</div>
          <div class="stat-value ">12,000</div>
          <div class="stat-desc text-primary">Next Harvest</div>
        </div>

        <div class="stat bg-base-100 border border-secondary rounded-box p-6">
          <div class="stat-figure "></div>
          <div class="stat-title text-lg">Transactions Today</div>
          <div class="stat-value">7,382,952</div>
          <div class="stat-desc">Number of transactions processed</div>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <!-- Map Section -->
        <div class="card border border-primary">
          <div class="card-body">
            <h2 class="card-title">Merchant Locations Map</h2>
            <AshPhoenixStarterWeb.Map.map />
          </div>
        </div>
        
    <!-- Low Stock Section -->
        <div class="card bg-base-100 border border-primary ">
          <div class="card-body">
            <h2 class="card-title">Actual vs Predicted Sales (Today)</h2>
            <AshPhoenixStarterWeb.Chart.chart />
          </div>
          <div class="divider" />
          <div class="card-body">
            <h2 class="card-title">Merchants About to Run Out of Stock</h2>
            <div class="overflow-x-auto">
              <table class="table">
                <thead>
                  <tr>
                    <th>Merchant Name</th>
                    <th>Product</th>
                    <th>Remaining Stock</th>
                    <th>Alert Level</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>Merchant A</td>
                    <td>Product X</td>
                    <td>{Money.new(7200, :xof)}</td>
                    <td><span class="badge badge-warning">Low</span></td>
                  </tr>
                  <tr>
                    <td>Merchant B</td>
                    <td>Product Y</td>
                    <td>{Money.new(7200, :xof)}</td>
                    <td><span class="badge badge-error">Critical</span></td>
                  </tr>
                  <tr>
                    <td>Merchant C</td>
                    <td>Product Z</td>
                    <td>{Money.new(3200, :xof)}</td>
                    <td><span class="badge badge-warning">Low</span></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

 @impl true
  def handle_info({:new_notification, count}, socket) do
    socket = 
      if count > 0 do
        # 1. Active State: Inject the SVG dynamic markup template onto our target ID
        svg_template = "data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><circle cx='50' cy='50' r='50' fill='{counter_background}' /><text x='50%' y='50%' text-anchor='middle' dominant-baseline='central' font-size='55' fill='white'>{counter}</text></svg>"
        
        socket
        # Turn off the path-based elements by blanking their reference attributes
        |> Favicon.set_dynamic("favicon-32", "subfolder", "blank")
        |> Favicon.set_dynamic("favicon-16", "subfolder", "blank")
        # Build and update the custom counter template
        |> Favicon.set_dynamic("dynamic-svg-favicon", "dynamic-href", svg_template)
        |> Favicon.set_dynamic("dynamic-svg-favicon", "counter", count)
        |> Favicon.set_dynamic("dynamic-svg-favicon", "counter_background", "red")
      else
        # 2. Fallback State: Strip the custom SVG and restore the subfolder routes
        socket
        |> Favicon.set_dynamic("dynamic-svg-favicon", "dynamic-href", "")
        |> Favicon.set_dynamic("favicon-32", "subfolder", "dashboard")
        |> Favicon.set_dynamic("favicon-16", "subfolder", "dashboard")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end
end
