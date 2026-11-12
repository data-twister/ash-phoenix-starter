defmodule AshPhoenixStarterWeb.ProductIndexLive do
  use AshPhoenixStarterWeb, :live_view

  require Ash.Query
  alias AshPhoenixStarter.Accounts.{Merchant, Vendor}
  alias AshPhoenixStarter.Core.Product

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    tenant = current_user.organization.domain

    if connected?(socket) do
      Phoenix.PubSub.subscribe(AshPhoenixStarter.PubSub, "products:#{tenant}")
    end

    vendors = Ash.read!(Vendor, tenant: tenant, actor: current_user)
    merchants = Ash.read!(Merchant, tenant: tenant, actor: current_user)

    {:ok,
     socket
     |> assign(:vendors, vendors)
     |> assign(:merchants, merchants)
     |> assign(:filters, %{"vendor_id" => "", "merchant_id" => "", "low_stock" => ""})
     |> assign(:filtered?, false)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = %{
      "vendor_id" => params["vendor_id"] || "",
      "merchant_id" => params["merchant_id"] || "",
      "low_stock" => params["low_stock"] || ""
    }

    {:noreply, load_filtered_products(socket, filters)}
  end

  @impl true
  def handle_event("filter", %{"filters" => filter_params}, socket) do
    clean_params =
      filter_params
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> Map.new()

    {:noreply, push_patch(socket, to: ~p"/products?#{clean_params}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user
    tenant = current_user.organization.domain

    with {:ok, product} <- Ash.get(Product, id, tenant: tenant, actor: current_user),
         :ok <- Ash.destroy(product, tenant: tenant, actor: current_user) do
      {:noreply,
       socket
       |> stream_delete(:products, product)
       |> put_flash(:info, "Product deleted successfully.")}
    else
      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not delete product.")}
    end
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{topic: "products:" <> broadcast_tenant, event: "updated"},
        socket
      ) do
    tenant = socket.assigns.current_user.organization.domain

    if broadcast_tenant == tenant do
      {:noreply, load_filtered_products(socket, socket.assigns.filters)}
    else
      {:noreply, socket}
    end
  end

  defp load_filtered_products(socket, filters) do
    current_user = socket.assigns.current_user
    tenant = current_user.organization.domain

    query =
      Product
      |> Ash.Query.load([:vendor, :merchant, :alert_level])
      |> maybe_filter_vendor(filters["vendor_id"])
      |> maybe_filter_merchant(filters["merchant_id"])
      |> maybe_filter_stock_level(filters["low_stock"])

    products = Ash.read!(query, tenant: tenant, actor: current_user)
    filtered? = Enum.any?(Map.values(filters), &(&1 != ""))

    socket
    |> assign(:filters, filters)
    |> assign(:filtered?, filtered?)
    |> stream(:products, products, reset: true)
  end

  defp maybe_filter_vendor(query, ""), do: query
  defp maybe_filter_vendor(query, vendor_id), do: Ash.Query.filter(query, vendor_id == ^vendor_id)

  defp maybe_filter_merchant(query, ""), do: query
  defp maybe_filter_merchant(query, merchant_id), do: Ash.Query.filter(query, merchant_id == ^merchant_id)

  defp maybe_filter_stock_level(query, "true"),
    do: Ash.Query.filter(query, remaining_stock <= low_stock_threshold)

  defp maybe_filter_stock_level(query, "critical"),
    do: Ash.Query.filter(query, remaining_stock <= critical_stock_threshold)

  defp maybe_filter_stock_level(query, _), do: query

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <div class="flex justify-between items-center mb-6">
        <div class="flex items-center gap-4">
          <h1 class="text-2xl font-bold">Products</h1>
          <.link
            :if={@filtered?}
            patch={~p"/products"}
            class="text-sm text-zinc-600 hover:text-zinc-900 underline"
          >
            Clear filters
          </.link>
        </div>

        <.link navigate={~p"/products/new"} class="btn btn-primary">New Product</.link>
      </div>

      <form phx-change="filter" class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6 p-4 border rounded-lg bg-zinc-50">
        <div>
          <label class="block text-xs font-medium text-zinc-600 mb-1">Vendor</label>
          <select name="filters[vendor_id]" class="w-full rounded-md border-zinc-300 text-sm">
            <option value="">All Vendors</option>
            <option
              :for={v <- @vendors}
              value={v.id}
              selected={@filters["vendor_id"] == v.id}
            >
              <%= v.name %>
            </option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-medium text-zinc-600 mb-1">Merchant</label>
          <select name="filters[merchant_id]" class="w-full rounded-md border-zinc-300 text-sm">
            <option value="">All Merchants</option>
            <option
              :for={m <- @merchants}
              value={m.id}
              selected={@filters["merchant_id"] == m.id}
            >
              <%= m.name %>
            </option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-medium text-zinc-600 mb-1">Stock Status</label>
          <select name="filters[low_stock]" class="w-full rounded-md border-zinc-300 text-sm">
            <option value="" selected={@filters["low_stock"] == ""}>All Stock Levels</option>
            <option value="true" selected={@filters["low_stock"] == "true"}>Low & Critical Stock</option>
            <option value="critical" selected={@filters["low_stock"] == "critical"}>Critical Stock Only</option>
          </select>
        </div>
      </form>

      <div id="products-list" phx-update="stream" class="divide-y border rounded-lg">
        <div class="hidden only:block p-6 text-center text-sm text-zinc-500">
          No matching products found.
        </div>

        <div
          :for={{dom_id, product} <- @streams.products}
          id={dom_id}
          class="p-4 flex justify-between items-start"
        >
          <div>
            <div class="flex items-center gap-2">
              <h2 class="font-semibold text-lg"><%= product.name %></h2>
              <span class={alert_badge_class(product.alert_level)}>
                <%= product.alert_level %>
              </span>
            </div>

            <p class="text-sm text-zinc-600 mt-1">
              Price: $<%= product.price %> · Remaining Stock: <%= product.remaining_stock %>
            </p>

            <p class="text-xs text-zinc-500 mt-1">
              Vendor: <%= (product.vendor && product.vendor.name) || "None" %> ·
              Merchant: <%= (product.merchant && product.merchant.name) || "None" %>
            </p>
          </div>

          <div class="flex items-center space-x-4">
            <.link navigate={~p"/products/#{product.id}/edit"} class="text-sm underline">
              Edit
            </.link>

            <button
              type="button"
              phx-click="delete"
              phx-value-id={product.id}
              data-confirm="Are you sure you want to delete this product?"
              class="text-sm text-red-600 hover:text-red-800 underline"
            >
              Delete
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp alert_badge_class(:critical),
    do: "px-2 py-0.5 text-xs font-medium bg-red-100 text-red-800 rounded-full"

  defp alert_badge_class(:low),
    do: "px-2 py-0.5 text-xs font-medium bg-amber-100 text-amber-800 rounded-full"

  defp alert_badge_class(_),
    do: "px-2 py-0.5 text-xs font-medium bg-emerald-100 text-emerald-800 rounded-full"
end
