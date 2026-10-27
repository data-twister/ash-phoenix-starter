defmodule AshPhoenixStarterWeb.Live.Locale do
  use Phoenix.LiveView

  def on_mount(:default, _params, session, socket) do
    # Pull locale set by the plug or fall back safely
    locale = session["cldr_locale"] || "en"

    # Set the thread/process-local locale for CLDR functions
    AshPhoenixStarter.Cldr.put_locale(locale)

    {:cont, assign(socket, :locale, locale)}
  end
end