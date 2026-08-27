defmodule AshPhoenixStarterWeb.Favicon.Counter do
  use AshPhoenixStarterWeb, :html

  attr :text_anchor, :string, default: "middle"
  attr :dominant_baseline, :string, default: "central"
  attr :x, :string, default: "50%"
  attr :y, :string, default: "50%"

  def counter(assigns) do
    ~H"""
    <link
      rel="icon"
      type="image/png"
      href="images/favicons/favicon-32x32.png"
      data-dynamic-href="data:image/svg+xml,
       <svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'>
         <circle cx='50' cy='50' r='50' fill='{counter_background}' />
         <text x={@x} y={@y} text-anchor={@text_anchor} dominant-baseline={@dominant_baseline}>
           {counter}
         </text>
       </svg>
    "
    />
    """
  end
end
