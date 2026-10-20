defmodule AshPhoenixStarterWeb.Stock do
  use AshPhoenixStarterWeb, :html

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
end
