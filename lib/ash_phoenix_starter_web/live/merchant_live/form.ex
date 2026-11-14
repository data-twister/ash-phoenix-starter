defmodule AshPhoenixStarterWeb.MerchantFormLive do
  use AshPhoenixStarterWeb, :live_view

  require Ash.Query
  alias AshPhoenixStarter.Accounts.Merchant
  alias AshPhoenixStarter.Core.{Region, RegionLocation}

  @impl true
  def mount(_params, _session, socket) do
    regions = Ash.read!(Region)

    {:ok,
     socket
     |> assign(:regions, regions)
     |> assign(:selected_region_id, nil)
     |> assign(:region_locations, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    current_user = socket.assigns.current_user
    tenant = current_user.organization.domain

    {form, region_id} =
      case socket.assigns.live_action do
        :new ->
          form =
            AshPhoenix.Form.for_create(Merchant, :create,
              as: "merchant",
              tenant: tenant,
              actor: current_user,
              params: %{"user_id" => current_user.id}
            )

          {form, nil}

        :edit ->
          merchant =
            Merchant
            |> Ash.get!(params["id"], tenant: tenant, actor: current_user)
            |> Ash.load!(:region_locations, tenant: tenant, actor: current_user)

          existing_location_ids = Enum.map(merchant.region_locations, & &1.id)

          form =
            AshPhoenix.Form.for_update(merchant, :update,
              as: "merchant",
              tenant: tenant,
              actor: current_user,
              params: %{"region_location_ids" => existing_location_ids}
            )

          {form, merchant.region_id}
      end

    {:noreply,
     socket
     |> assign(
       :page_title,
       if(socket.assigns.live_action == :new, do: "New Merchant", else: "Edit Merchant")
     )
     |> assign(:selected_region_id, region_id)
     |> assign(:region_locations, load_locations_for_region(region_id))
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"merchant" => merchant_params}, socket) do
    new_region_id = blank_to_nil(merchant_params["region_id"])
    old_region_id = socket.assigns.selected_region_id

    {merchant_params, locations} =
      if new_region_id != old_region_id do
        {Map.put(merchant_params, "region_location_ids", []),
         load_locations_for_region(new_region_id)}
      else
        {Map.put_new(merchant_params, "region_location_ids", []), socket.assigns.region_locations}
      end

    form = AshPhoenix.Form.validate(socket.assigns.form, merchant_params)

    {:noreply,
     socket
     |> assign(:selected_region_id, new_region_id)
     |> assign(:region_locations, locations)
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("save", %{"merchant" => merchant_params}, socket) do
    merchant_params = Map.put_new(merchant_params, "region_location_ids", [])

    case AshPhoenix.Form.submit(socket.assigns.form, params: merchant_params) do
      {:ok, _merchant} ->
        {:noreply,
         socket
         |> put_flash(:info, "Merchant saved successfully.")
         |> push_navigate(to: ~p"/merchants")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  defp load_locations_for_region(nil), do: []

  defp load_locations_for_region(region_id) do
    RegionLocation
    |> Ash.Query.filter(region_id == ^region_id)
    |> Ash.Query.sort(:value)
    |> Ash.read!()
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(val), do: val

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6">
      <h1 class="text-2xl font-bold mb-6">{@page_title}</h1>

      <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
        <.input field={@form[:user_id]} type="hidden" />
        <.input
          field={@form[:name]}
          type="text"
          label="Merchant Name"
          placeholder="Tucson Outfitters"
        />
        <div class="grid grid-cols-2 gap-4">
          <.input
            field={@form[:country_code]}
            type="text"
            label="Country Code (ISO-2)"
            placeholder="US"
          />
          <.input field={@form[:region_name]} type="text" label="Region Name" placeholder="Arizona" />
        </div>

        <.input
          field={@form[:region_id]}
          type="select"
          label="Primary Region"
          options={Enum.map(@regions, &{&1.name, &1.id})}
          prompt="Select a region"
        />
        <div>
          <label class="block text-sm font-semibold leading-6 text-zinc-800 mb-2">
            Serviceable Region Locations
          </label>
          <div :if={is_nil(@selected_region_id)} class="text-sm text-zinc-500 border rounded-lg p-3">
            Select a primary region above to view available locations.
          </div>

          <div
            :if={@selected_region_id && @region_locations == []}
            class="text-sm text-zinc-500 border rounded-lg p-3"
          >
            No locations registered for this region yet.
          </div>

          <div
            :if={@region_locations != []}
            class="grid grid-cols-2 gap-2 max-h-60 overflow-y-auto border rounded-lg p-3"
          >
            <% selected_ids = List.wrap(@form[:region_location_ids].value) %>
            <label
              :for={loc <- @region_locations}
              class="flex items-center space-x-2 text-sm cursor-pointer"
            >
              <input
                type="checkbox"
                name="merchant[region_location_ids][]"
                value={loc.id}
                checked={loc.id in selected_ids}
                class="rounded border-zinc-300 text-zinc-900 focus:ring-0"
              /> <span>{loc.value} ({loc.type})</span>
            </label>
          </div>
        </div>

        <div class="pt-4"><.button type="submit">Save Merchant</.button></div>
      </.form>
    </div>
    """
  end
end
