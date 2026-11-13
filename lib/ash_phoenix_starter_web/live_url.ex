defmodule AshPhoenixStarterWeb.LiveUri do
  @moduledoc """
  LiveView on_mount hook that keeps `@uri` assigned as a `%URI{}` struct
  for sidebar navigation active-state highlighting.
  """
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign_new(:uri, fn -> %URI{path: "/"} end)
      |> attach_hook(:save_request_uri, :handle_params, fn _params, uri, socket ->
        {:cont, assign(socket, :uri, URI.parse(uri))}
      end)

    {:cont, socket}
  end
end
