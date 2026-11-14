defmodule AshPhoenixStarterWeb.InventoryDashboardLive do
  use AshPhoenixStarterWeb, :live_view

  alias AshPhoenixStarter.Accounts.{Merchant, Vendor}
  alias AshPhoenixStarter.Core.Product

  on_mount {AshPhoenixStarterWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]
    tenant = current_user.organization.domain

    if connected?(socket) do
      Phoenix.PubSub.subscribe(AshPhoenixStarter.PubSub, "products:#{tenant}")
    end

    country_codes =
      Merchant
      |> Ash.read!(tenant: tenant, actor: current_user)
      |> Enum.map(& &1.country_code)
      |> Enum.uniq()
      |> Enum.sort()

    {:ok,
     socket
     |> assign(:country_codes, country_codes)
     |> assign(:selected_country, "")
     |> assign(:metrics, [])
     |> assign(:total_stock, 0)
     |> assign(:total_vendors, Ash.count!(Vendor, tenant: tenant, actor: current_user))
     |> assign(:total_merchants, Ash.count!(Merchant, tenant: tenant, actor: current_user))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    country_code = params["country_code"] || ""
    {:noreply, load_metrics(socket, country_code)}
  end

  @impl true
  def handle_event("select_country", %{"country_code" => country_code}, socket) do
    if country_code == "" do
      {:noreply, push_patch(socket, to: ~p"/inventory/dashboard")}
    else
      {:noreply, push_patch(socket, to: ~p"/inventory/dashboard?#{[country_code: country_code]}")}
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_metrics(socket, socket.assigns.selected_country)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{topic: "products:" <> broadcast_tenant, event: "updated"},
        socket
      ) do
    current_user = socket.assigns[:current_user]
    tenant = current_user.organization.domain

    if broadcast_tenant == tenant do
      {:noreply,
       socket
       |> assign(:total_vendors, Ash.count!(Vendor, tenant: tenant, actor: current_user))
       |> assign(:total_merchants, Ash.count!(Merchant, tenant: tenant, actor: current_user))
       |> load_metrics(socket.assigns.selected_country)}
    else
      {:noreply, socket}
    end
  end

  defp load_metrics(socket, country_code) do
    current_user = socket.assigns[:current_user]
    tenant = current_user.organization.domain
    opts = [tenant: tenant, actor: current_user]

    result =
      if country_code == "" do
        Product.get_all_live_metrics(opts)
      else
        Product.get_live_metrics_for_country(country_code, opts)
      end

    case result do
      {:ok, metrics_map} ->
        sorted_metrics = Enum.sort_by(metrics_map, fn {_region, qty} -> qty end, :desc)
        total_stock = Enum.reduce(metrics_map, 0, fn {_region, qty}, acc -> acc + qty end)

        socket
        |> assign(:selected_country, country_code)
        |> assign(:metrics, sorted_metrics)
        |> assign(:total_stock, total_stock)

      {:error, _error} ->
        socket
        |> put_flash(:error, "Unable to load regional inventory metrics.")
        |> assign(:metrics, [])
        |> assign(:total_stock, 0)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
        <div>
          <h1 class="text-2xl font-bold">Regional Inventory Dashboard</h1>

          <p class="text-sm text-zinc-500 mt-1">
            Live remaining stock aggregated across merchant regions
          </p>
        </div>

        <div class="flex flex-wrap items-center gap-2">
          <.link navigate={~p"/vendors"} class="px-3 py-2 text-sm border rounded-md hover:bg-zinc-50">
            Vendors ({@total_vendors})
          </.link>
          <.link
            navigate={~p"/merchants"}
            class="px-3 py-2 text-sm border rounded-md hover:bg-zinc-50"
          >
            Merchants ({@total_merchants})
          </.link>
          <.link navigate={~p"/products"} class="px-3 py-2 text-sm border rounded-md hover:bg-zinc-50">
            Products
          </.link>
        </div>
      </div>

      <div class="flex items-center justify-end gap-3 mb-6">
        <form phx-change="select_country">
          <select
            name="country_code"
            class="rounded-md border-zinc-300 text-sm"
            aria-label="Filter by country"
          >
            <option value="" selected={@selected_country == ""}>All Countries</option>

            <option
              :for={code <- @country_codes}
              value={code}
              selected={@selected_country == code}
            >
              {code}
            </option>
          </select>
        </form>

        <button
          type="button"
          phx-click="refresh"
          class="px-3 py-2 text-sm border rounded-md hover:bg-zinc-50"
        >
          Refresh
        </button>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6">
        <div class="p-4 border rounded-lg bg-zinc-50">
          <p class="text-xs font-medium uppercase tracking-wider text-zinc-500">
            Total Remaining Stock
          </p>

          <p class="text-3xl font-bold mt-1">{@total_stock}</p>
        </div>

        <div class="p-4 border rounded-lg bg-zinc-50">
          <p class="text-xs font-medium uppercase tracking-wider text-zinc-500">Active Regions</p>

          <p class="text-3xl font-bold mt-1">{length(@metrics)}</p>
        </div>
      </div>

      <div class="border rounded-lg divide-y">
        <div :if={@metrics == []} class="p-6 text-center text-sm text-zinc-500">
          No regional stock metrics available for this selection.
        </div>

        <div :for={{region_name, qty} <- @metrics} class="p-4">
          <div class="flex justify-between items-center text-sm mb-2">
            <span class="font-semibold text-zinc-900">{region_name}</span>
            <span class="font-mono text-zinc-700">{qty} units</span>
          </div>

          <div class="w-full bg-zinc-100 rounded-full h-2.5 overflow-hidden">
            <% pct = if @total_stock > 0, do: Float.round(qty / @total_stock * 100, 1), else: 0 %>
            <div class="bg-zinc-900 h-2.5 rounded-full" style={"width: #{pct}%"}></div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
