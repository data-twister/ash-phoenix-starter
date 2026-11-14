defmodule AshPhoenixStarter.Application do
  @moduledoc false

  use Application

  alias AshPhoenixStarter.Cache.{AppSettings, TenantSettings, TimezoneResolution}

  @impl true
  def start(_type, _args) do
    children =
      timezone_cache_children() ++
        [
          Cldr.Currency,
          AshPhoenixStarterWeb.Telemetry,
          AshPhoenixStarter.Repo,
          {DNSCluster,
           query: Application.get_env(:ash_phoenix_starter, :dns_cluster_query) || :ignore},
          {Phoenix.PubSub, name: AshPhoenixStarter.PubSub},
          {Oban,
           AshOban.config(
             Application.fetch_env!(:ash_phoenix_starter, :ash_domains),
             Application.fetch_env!(:ash_phoenix_starter, Oban)
           )},
          AshPhoenixStarter.Accounts.PasswordResetScheduler,
          cache_child_spec(AppSettings, :app_settings_cache, :global_cache_config,
            gc_interval: :timer.seconds(120),
            max_size: 10_000
          ),
          cache_child_spec(TenantSettings, :tenant_settings_cache, :tenant_cache_config,
            gc_interval: :timer.seconds(60),
            max_size: 50_000
          ),
          AshPhoenixStarterWeb.Presence,
          AshPhoenixStarterWeb.Endpoint,
          {AshAuthentication.Supervisor, [otp_app: :ash_phoenix_starter]}
        ]

    opts = [strategy: :one_for_one, name: AshPhoenixStarter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    AshPhoenixStarterWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp timezone_cache_children do
    if Application.get_env(:ash_phoenix_starter, :timezone_cache_config) do
      [
        cache_child_spec(
          TimezoneResolution,
          :timezone_resolution_cache,
          :timezone_cache_config,
          gc_interval: :timer.hours(1),
          max_size: 5_000
        )
      ]
    else
      []
    end
  end

  defp cache_child_spec(module, name, config_key, defaults) do
    env_cfg = Application.get_env(:ash_phoenix_starter, config_key, [])

    opts = [
      name: name,
      gc_interval: Keyword.get(env_cfg, :ttl_check_interval, defaults[:gc_interval]),
      max_size: Keyword.get(env_cfg, :max_size, defaults[:max_size])
    ]

    Supervisor.child_spec({module, opts}, id: name)
  end
end
