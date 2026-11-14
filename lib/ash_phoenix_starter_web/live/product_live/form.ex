defmodule AshPhoenixStarterWeb.ProductFormLive do
  use AshPhoenixStarterWeb, :live_view

  alias AshPhoenixStarter.Accounts.{Merchant, Vendor}
  alias AshPhoenixStarter.Core.Product

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    tenant = current_user.organization.domain

    vendors = Ash.read!(Vendor, tenant: tenant, actor: current_user)
    merchants = Ash.read!(Merchant, tenant: tenant, actor: current_user)

    {:ok,
     socket
     |> assign(:vendors, vendors)
     |> assign(:merchants, merchants)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    current_user = socket.assigns.current_user
    tenant = current_user.organization.domain

    form =
      case socket.assigns.live_action do
        :new ->
          AshPhoenix.Form.for_create(Product, :create,
            as: "product",
            tenant: tenant,
            actor: current_user
          )

        :edit ->
          product = Ash.get!(Product, params["id"], tenant: tenant, actor: current_user)

          AshPhoenix.Form.for_update(product, :update,
            as: "product",
            tenant: tenant,
            actor: current_user
          )
      end

    {:noreply,
     socket
     |> assign(
       :page_title,
       if(socket.assigns.live_action == :new, do: "New Product", else: "Edit Product")
     )
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"product" => product_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, product_params)
    {:noreply, assign(socket, :form, to_form(form))}
  end

  @impl true
  def handle_event("save", %{"product" => product_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: product_params) do
      {:ok, _product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product saved successfully.")
         |> push_navigate(to: ~p"/products")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6">
      <h1 class="text-2xl font-bold mb-6">{@page_title}</h1>

      <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
        <.input field={@form[:name]} type="text" label="Product Name" placeholder="Solar Panel Kit" />
        <div class="grid grid-cols-2 gap-4">
          <.input
            field={@form[:vendor_id]}
            type="select"
            label="Vendor"
            options={Enum.map(@vendors, &{&1.name, &1.id})}
            prompt="Select a vendor"
          />
          <.input
            field={@form[:merchant_id]}
            type="select"
            label="Merchant"
            options={Enum.map(@merchants, &{&1.name, &1.id})}
            prompt="Select a merchant"
          />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:price]} type="number" label="Price" />
          <.input field={@form[:remaining_stock]} type="number" label="Remaining Stock" />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:low_stock_threshold]} type="number" label="Low Stock Threshold" />
          <.input
            field={@form[:critical_stock_threshold]}
            type="number"
            label="Critical Stock Threshold"
          />
        </div>

        <div class="pt-4"><.button type="submit">Save Product</.button></div>
      </.form>
    </div>
    """
  end
end
