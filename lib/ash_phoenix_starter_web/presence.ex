defmodule AshPhoenixStarterWeb.Presence do
  use Phoenix.Presence,
    otp_app: :AshPhoenixStarter,
    pubsub_server: AshPhoenixStarter.PubSub
end
