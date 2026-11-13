defmodule AshPhoenixStarterWeb.VendorIndexLive do
  use AshPhoenixStarterWeb, :live_view

  alias AshPhoenixStarter.Accounts.Vendor

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    tenant = current_user.organization.domain

    if connected?(socket) do
      Phoenix.PubSub.subscribe(AshPhoenixStarter.PubSub, "products:#{tenant}")
    end

    {:ok, stream(socket, :vendors, load_vendors(tenant, current_user))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user
    tenant = current_user.organization.domain

    with {:ok, vendor} <- Ash.get(Vendor, id, tenant: tenant, actor: current_user),
         :ok <- Ash.destroy(vendor, tenant: tenant, actor: current_user) do
      {:noreply,
       socket
       |> stream_delete(:vendors, vendor)
       |> put_flash(:info, "Vendor deleted successfully.")}
    else
      {:error, %Ash.Error.Forbidden{}} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to delete this vendor.")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not delete vendor.")}
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
      {:noreply, stream(socket, :vendors, load_vendors(tenant, current_user), reset: true)}
    else
      {:noreply, socket}
    end
  end

  defp load_vendors(tenant, current_user) do
    Vendor
    |> Ash.Query.load([:region_locations, :total_low_stock])
    |> Ash.read!(tenant: tenant, actor: current_user)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold">Vendors</h1>
        <.link navigate={~p"/vendors/new"} class="btn btn-primary">New Vendor</.link>
      </div>

      <div id="vendors-list" phx-update="stream" class="divide-y border rounded-lg">
        <div class="hidden only:block p-6 text-center text-sm text-zinc-500">
          No vendors found. Create your first vendor to get started.
        </div>

        <div
          :for={{dom_id, vendor} <- @streams.vendors}
          id={dom_id}
          class="p-4 flex justify-between items-start"
        >
          <div>
            <div class="flex items-center gap-2">
              <h2 class="font-semibold text-lg"><%= vendor.name %></h2>
              <.link
                :if={is_integer(vendor.total_low_stock) and vendor.total_low_stock > 0}
                navigate={~p"/products?#{[vendor_id: vendor.id, low_stock: true]}"}
                class="px-2 py-0.5 text-xs font-medium bg-amber-100 text-amber-800 hover:bg-amber-200 rounded-full underline"
              >
                <%= vendor.total_low_stock %> low stock
              </.link>
              <span
                :if={!is_integer(vendor.total_low_stock) or vendor.total_low_stock == 0}
                class="px-2 py-0.5 text-xs font-medium bg-emerald-100 text-emerald-800 rounded-full"
              >
                Stock OK
              </span>
            </div>

            <p class="text-sm text-zinc-500">
              <%= vendor.region_name %> (<%= vendor.country_code %>)
            </p>
            <div class="flex flex-wrap gap-1 mt-2">
              <span
                :for={loc <- vendor.region_locations}
                class="px-2 py-0.5 text-xs bg-zinc-100 rounded-full"
              >
                <%= loc.value %>
              </span>
            </div>
          </div>

          <div class="flex items-center space-x-4">
            <.link navigate={~p"/vendors/#{vendor.id}/edit"} class="text-sm underline">
              Edit
            </.link>

            <button
              :if={vendor.user_id == @current_user.id}
              type="button"
              phx-click="delete"
              phx-value-id={vendor.id}
              data-confirm="Are you sure you want to delete this vendor?"
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
