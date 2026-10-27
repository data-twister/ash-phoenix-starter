defmodule AshPhoenixStarterWeb.Live.Hooks.NotificationHook do
  import Phoenix.LiveView
  alias Phx.Live.Favicon

  def on_mount(:default, _params, _session, socket) do
    # 1. Subscribe to the notification channel only on active websocket connect
    if connected?(socket) do
      Phoenix.PubSub.subscribe(AshPhoenixStarter.PubSub, "notifications:alerts")
    end

    # 2. Attach a message intercept hook to capture the handle_info event globally
    socket =
      attach_hook(socket, :favicon_notifier, :handle_info, fn
        {:new_notification, count}, socket ->
          socket = update_favicon_layout(socket, count)
          # :halt stops the message from bubbling to the base LiveView
          {:halt, socket}

        _other_message, socket ->
          # Let other unrelated handle_info messages pass through
          {:cont, socket}
      end)

    {:cont, socket}
  end

  # Helper function containing your core swapping logic
  defp update_favicon_layout(socket, count) do
    if count > 0 do
      svg_template =
        "data:image/svg+xml,<svg xmlns='http://w3.org' viewBox='0 0 100 100'><circle cx='50' cy='50' r='50' fill='{counter_background}' /><text x='50%' y='50%' text-anchor='middle' dominant-baseline='central' font-size='55' fill='white'>{counter}</text></svg>"

      socket
      |> Favicon.set_dynamic("favicon-32", "subfolder", "blank")
      |> Favicon.set_dynamic("favicon-16", "subfolder", "blank")
      |> Favicon.set_dynamic("dynamic-svg-favicon", "dynamic-href", svg_template)
      |> Favicon.set_dynamic("dynamic-svg-favicon", "counter", count)
      |> Favicon.set_dynamic("dynamic-svg-favicon", "counter_background", "red")
    else
      # Automatically extracts a folder string name based on your module naming rules
      # e.g., AshPhoenixStarterWeb.DashboardLive -> "dashboard"
      # e.g., AshPhoenixStarterWeb.SettingsLive -> "settings"
      current_page_folder =
        socket.view
        |> Module.split()
        |> List.last()
        |> String.replace("Live", "")
        |> String.downcase()

      socket
      |> Favicon.set_dynamic("dynamic-svg-favicon", "dynamic-href", "")
      |> Favicon.set_dynamic("favicon-32", "subfolder", current_page_folder)
      |> Favicon.set_dynamic("favicon-16", "subfolder", current_page_folder)
    end
  end
end
