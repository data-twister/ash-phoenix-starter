defmodule AshPhoenixStarter.Application do
  @moduledoc false

  use Application
  import Cachex.Spec

  @impl true
  def start(_type, _args) do
    global_config = Application.get_env(:ash_phoenix_starter, :global_cache_config, [])
    ttl_check = Keyword.get(global_config, :ttl_check_interval, :timer.seconds(120))
    global_ttl = Keyword.get(global_config, :global_ttl, :timer.minutes(60))
    global_limit = Keyword.get(global_config, :max_size, 10_000)

    tenant_config = Application.get_env(:ash_phoenix_starter, :tenant_cache_config, [])
    tenant_ttl_check = Keyword.get(tenant_config, :ttl_check_interval, :timer.seconds(60))
    tenant_global_ttl = Keyword.get(tenant_config, :global_ttl, :timer.minutes(30))
    tenant_limit = Keyword.get(tenant_config, :max_size, 50_000)

    timezone_config = Application.get_env(:ash_phoenix_starter, :timezone_cache_config)

    timezone_resolution_children =
      if timezone_config do
        tz_ttl_check = Keyword.get(timezone_config, :ttl_check_interval, :timer.hours(1))
        tz_global_ttl = Keyword.get(timezone_config, :global_ttl, :timer.hours(24))
        tz_limit = Keyword.get(timezone_config, :max_size, 5_000)

        [
          Supervisor.child_spec(
            {Cachex,
             [
               name: :timezone_resolution_cache,
               expiration:
                 expiration(
                   default: tz_global_ttl,
                   interval: tz_ttl_check,
                   lazy: true
                 ),
               hooks: [
                 hook(
                   module: Cachex.Limit.Scheduled,
                   args: {
                     tz_limit,
                     [policy: Cachex.Policy.LRW, reclaim: 0.1],
                     [frequency: :timer.seconds(30)]
                   }
                 )
               ]
             ]},
            id: :timezone_resolution_cache
          )
        ]
      else
        []
      end

    children = [
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
      Supervisor.child_spec(
        {Cachex,
         [
           name: :app_settings_cache,
           expiration:
             expiration(
               default: global_ttl,
               interval: ttl_check,
               lazy: true
             ),
           hooks: [
             hook(
               module: Cachex.Limit.Scheduled,
               args: {
                 global_limit,
                 [policy: Cachex.Policy.LRW, reclaim: 0.1],
                 [frequency: :timer.seconds(10)]
               }
             )
           ]
         ]},
        id: :app_settings_cache
      ),
      Supervisor.child_spec(
        {Cachex,
         [
           name: :tenant_settings_cache,
           expiration:
             expiration(
               default: tenant_global_ttl,
               interval: tenant_ttl_check,
               lazy: true
             ),
           hooks: [
             hook(
               module: Cachex.Limit.Scheduled,
               args: {
                 tenant_limit,
                 [policy: Cachex.Policy.LRW, reclaim: 0.1],
                 [frequency: :timer.seconds(10)]
               }
             )
           ]
         ]},
        id: :tenant_settings_cache
      ),
      AshPhoenixStarterWeb.Presence,
      AshPhoenixStarterWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :ash_phoenix_starter]}
    ]

    children = timezone_resolution_children ++ children

    opts = [strategy: :one_for_one, name: AshPhoenixStarter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    AshPhoenixStarterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
