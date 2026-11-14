defmodule AshPhoenixStarter.Cache.TimezoneResolution do
  @moduledoc """
  Local generational cache for coordinate-to-timezone lookups.
  """

  use Nebulex.Cache,
    otp_app: :ash_phoenix_starter,
    adapter: Nebulex.Adapters.Local

  @doc """
  Returns the configured TTL for timezone entries (defaults to 24 hours).
  """
  @spec default_ttl() :: pos_integer()
  def default_ttl do
    :ash_phoenix_starter
    |> Application.get_env(:timezone_cache_config, [])
    |> Keyword.get(:global_ttl, :timer.hours(24))
  end

  @doc """
  Fetches `key` from the timezone cache, computing and storing it via `resolver_fun` on miss.
  If the cache is disabled (`:timezone_cache_config` is `nil`), falls back to calling `resolver_fun` directly.
  """
  @spec fetch(term(), (-> term())) :: term()
  def fetch(key, resolver_fun) when is_function(resolver_fun, 0) do
    if Process.whereis(:timezone_resolution_cache) do
      case get(key) do
        nil ->
          value = resolver_fun.()
          if value != nil, do: put(key, value, ttl: default_ttl())
          value

        cached ->
          cached
      end
    else
      resolver_fun.()
    end
  end
end
