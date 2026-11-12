defmodule AshPhoenixStarterWeb.MerchantIndexLive do
  use AshPhoenixStarterWeb, :live_view

  alias AshPhoenixStarter.Accounts.Merchant

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    tenant = current_user.organization.domain

    if connected?(socket) do
      Phoenix.PubSub.subscribe(AshPhoenixStarter.PubSub, "products:#{tenant}")
    end

    {:ok, stream(socket, :merchants, load_merchants(tenant, current_user))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user
    tenant = current_user.organization.domain

    with {:ok, merchant} <- Ash.get(Merchant, id, tenant: tenant, actor: current_user),
         :ok <- Ash.destroy(merchant, tenant: tenant, actor: current_user) do
      {:noreply,
       socket
       |> stream_delete(:merchants, merchant)
       |> put_flash(:info, "Merchant deleted successfully.")}
    else
      {:error, %Ash.Error.Forbidden{}} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to delete this merchant.")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not delete merchant.")}
    end
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{topic: "products:" <> broadcast_tenant, event: "updated"},
        socket
      ) do
    current_user = socket.assigns.current_user
    tenant = current_user.organization.domain

    if broadcast_tenant == tenant do
      {:noreply, stream(socket, :merchants, load_merchants(tenant, current_user), reset: true)}
    else
      {:noreply, socket}
    end
  end

  defp load_merchants(tenant, current_user) do
    Merchant
    |> Ash.Query.load([:region_locations, :total_low_stock])
    |> Ash.read!(tenant: tenant, actor: current_user)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold">Merchants</h1>
        <.link navigate={~p"/merchants/new"} class="btn btn-primary">New Merchant</.link>
      </div>

      <div id="merchants-list" phx-update="stream" class="divide-y border rounded-lg">
        <div class="hidden only:block p-6 text-center text-sm text-zinc-500">
          No merchants found. Create your first merchant to get started.
        </div>

        <div
          :for={{dom_id, merchant} <- @streams.merchants}
          id={dom_id}
          class="p-4 flex justify-between items-start"
        >
          <div>
            <div class="flex items-center gap-2">
              <h2 class="font-semibold text-lg"><%= merchant.name %></h2>
              <.link
                :if={is_integer(merchant.total_low_stock) and merchant.total_low_stock > 0}
                navigate={~p"/products?#{[merchant_id: merchant.id, low_stock: true]}"}
                class="px-2 py-0.5 text-xs font-medium bg-amber-100 text-amber-800 hover:bg-amber-200 rounded-full underline"
              >
                <%= merchant.total_low_stock %> low stock
              </.link>
              <span
                :if={!is_integer(merchant.total_low_stock) or merchant.total_low_stock == 0}
                class="px-2 py-0.5 text-xs font-medium bg-emerald-100 text-emerald-800 rounded-full"
              >
                Stock OK
              </span>
            </div>

            <p class="text-sm text-zinc-500">
              <%= merchant.region_name %> (<%= merchant.country_code %>)
            </p>
            <div class="flex flex-wrap gap-1 mt-2">
              <span
                :for={loc <- merchant.region_locations}
                class="px-2 py-0.5 text-xs bg-zinc-100 rounded-full"
              >
                <%= loc.value %>
              </span>
            </div>
          </div>

          <div class="flex items-center space-x-4">
            <.link navigate={~p"/merchants/#{merchant.id}/edit"} class="text-sm underline">
              Edit
            </.link>

            <button
              :if={merchant.user_id == @current_user.id}
              type="button"
              phx-click="delete"
              phx-value-id={merchant.id}
              data-confirm="Are you sure you want to delete this merchant?"
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
end
