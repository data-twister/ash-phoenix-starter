defmodule AshPhoenixStarter.Cache.AppSettings do
  @moduledoc "Local generational cache for global application settings."
  use Nebulex.Cache,
    otp_app: :ash_phoenix_starter,
    adapter: Nebulex.Adapters.Local

  def default_ttl do
    :ash_phoenix_starter
    |> Application.get_env(:global_cache_config, [])
    |> Keyword.get(:global_ttl, :timer.minutes(60))
  end    
end