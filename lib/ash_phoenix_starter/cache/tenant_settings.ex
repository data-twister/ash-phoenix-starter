defmodule AshPhoenixStarter.Cache.TenantSettings do
  @moduledoc "Local generational cache for per-tenant settings."
  use Nebulex.Cache,
    otp_app: :ash_phoenix_starter,
    adapter: Nebulex.Adapters.Local

  def default_ttl do
    :ash_phoenix_starter
    |> Application.get_env(:tenant_cache_config, [])
    |> Keyword.get(:global_ttl, :timer.minutes(30))
  end    
end