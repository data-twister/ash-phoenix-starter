defmodule AshPhoenixStarterWeb.Presence do
  use Phoenix.Presence,
    otp_app: :ash_phoenix_starter,
    pubsub_server: AshPhoenixStarter.PubSub
end
