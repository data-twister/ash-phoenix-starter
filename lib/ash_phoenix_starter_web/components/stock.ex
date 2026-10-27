defmodule AshPhoenixStarterWeb.Stock do
  use AshPhoenixStarterWeb, :html

  @doc """
  Master render function that switches views based on the @stock_status assign.
  Expects @stock_status to be either :healthy or :low.
  """
  def render(%{stock_status: :low} = assigns), do: low(assigns)
  def render(%{stock_status: :healthy} = assigns), do: healthy(assigns)

  def render(assigns) do
    ~H"""
    <div class="text-center p-4 text-gray-500">{gettext("Unknown stock status configuration")}</div>
    """
  end

  def low(assigns) do
    ~H"""
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
              <%= for merchant <- @merchants do %>
                <%= for product <- merchant.products do %>
                  <tr>
                    <td class="font-medium">{merchant.name}</td>

                    <td>{product.name}</td>

                    <td>{Money.new(product.price, @currency)}</td>

                    <td>
                      <span class={[
                        "badge",
                        product.alert_level == "Critical" && "badge-error",
                        product.alert_level == "Low" && "badge-warning"
                      ]}>
                        {product.alert_level}
                      </span>
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  def healthy(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300">
      <div class="card-body">
        <h2 class="card-title">Actual vs Predicted Sales (Today)</h2>
        <AshPhoenixStarterWeb.Chart.chart />
      </div>
      <div class="divider" />
      <div class="card-body">
        <h2 class="card-title">Merchants with Healthy Stock</h2>

        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Merchant Name</th>

                <th>Product</th>

                <th>Current Stock</th>

                <th>Status</th>
              </tr>
            </thead>

            <tbody>
              <%= for merchant <- @merchants do %>
                <%= for product <- merchant.products do %>
                  <tr>
                    <td class="font-medium">{merchant.name}</td>

                    <td>{product.name}</td>

                    <td>{Money.new(product.price, @currency)}</td>

                    <td>
                      <span class="badge badge-success text-white">
                        {product.alert_level || "Healthy"}
                      </span>
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
end
