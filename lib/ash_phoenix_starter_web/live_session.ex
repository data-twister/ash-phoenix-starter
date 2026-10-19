defmodule AshPhoenixStarterWeb.Live.Session do
  use Phoenix.LiveView

  def on_mount(:default, _params, session, socket) do
    # Pass the session map directly into Cldr.Plug
    case Cldr.Plug.put_locale_from_session(session) do
      {:ok, locale} ->
        {:cont, assign(socket, :locale, locale)}

      {:error, _reason} ->
        # Fallback gracefully if no locale is found in the session
        {:cont, assign(socket, :locale, "en")}
    end
  end
end