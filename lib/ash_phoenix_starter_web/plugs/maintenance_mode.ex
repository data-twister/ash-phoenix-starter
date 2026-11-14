defmodule AshPhoenixStarterWeb.Plugs.MaintenanceMode do
  @moduledoc """
  Checks `Settings.Manager.get(:maintenance_mode)` from ConCache.
  When enabled, allows authentication and settings routes (plus admin users)
  while returning a 503 Maintenance page for regular traffic.
  """

  import Plug.Conn

  alias AshPhoenixStarter.Settings.Manager

  # Always allow auth & settings paths so admins can sign in and disable maintenance mode
  @exempt_prefixes ["/auth", "/sign-in", "/settings", "/challenge", "/dev"]

  def init(opts), do: opts

  def call(conn, _opts) do
    if maintenance_enabled?() and not exempt_request?(conn) do
      render_maintenance_response(conn)
    else
      conn
    end
  end

  defp maintenance_enabled? do
    Manager.get(:maintenance_mode) == true
  end

  defp exempt_request?(conn) do
    exempt_path?(conn.request_path) or admin_user?(conn.assigns[:current_user])
  end

  defp exempt_path?(path) do
    Enum.any?(@exempt_prefixes, &String.starts_with?(path, &1))
  end

  # Adjust this pattern if your User resource uses a different role/admin attribute
  defp admin_user?(%{role: role}) when role in [:admin, "admin", :superadmin, "superadmin"],
    do: true

  defp admin_user?(%{is_admin: true}), do: true
  defp admin_user?(_), do: false

  defp render_maintenance_response(conn) do
    if json_request?(conn) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        503,
        Jason.encode!(%{error: "Service temporarily unavailable for maintenance."})
      )
      |> halt()
    else
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(503, maintenance_html())
      |> halt()
    end
  end

  defp json_request?(conn) do
    String.starts_with?(conn.request_path, "/api") or
      Enum.any?(get_req_header(conn, "accept"), &String.contains?(&1, "application/json"))
  end

  defp maintenance_html do
    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Scheduled Maintenance</title>
        <style>
          body { font-family: system-ui, sans-serif; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; background: #f8fafc; color: #0f172a; }
          .card { max-width: 440px; padding: 2rem; background: white; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.06); text-align: center; }
          h1 { font-size: 1.5rem; margin-bottom: 0.5rem; }
          p { color: #475569; line-height: 1.5; }
        </style>
      </head>
      <body>
        <div class="card">
          <h1>We'll be right back</h1>
          <p>The system is currently undergoing scheduled maintenance. Please check back shortly.</p>
        </div>
      </body>
    </html>
    """
  end
end
