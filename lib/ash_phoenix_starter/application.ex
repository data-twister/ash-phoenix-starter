defmodule AshPhoenixStarter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    global_config = Application.get_env(:ash_phoenix_starter, :global_cache_config, [])
    ttl_check = Keyword.get(global_config, :ttl_check_interval, :timer.seconds(120))
    global_ttl = Keyword.get(global_config, :global_ttl, :timer.minutes(60))

    tenant_config = Application.get_env(:ash_phoenix_starter, :tenant_cache_config, [])
    tenant_ttl_check = Keyword.get(tenant_config, :ttl_check_interval, :timer.seconds(60))
    tenant_global_ttl = Keyword.get(tenant_config, :global_ttl, :timer.minutes(30))

    timezone_config = Application.get_env(:ash_phoenix_starter, :timezone_cache_config)

    timezone_resolution_children =
      if timezone_config do
        tz_ttl_check = Keyword.get(timezone_config, :ttl_check_interval, 3600)
        tz_global_ttl = Keyword.get(timezone_config, :global_ttl, 86400)

        [
          Supervisor.child_spec(
            {ConCache,
             [
               name: :timezone_resolution_cache,
               ttl_check_interval: tz_ttl_check,
               global_ttl: tz_global_ttl
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
      {Oban,
       AshOban.config(
         Application.fetch_env!(:ash_phoenix_starter, :ash_domains),
         Application.fetch_env!(:ash_phoenix_starter, Oban)
       )},
      AshPhoenixStarter.Accounts.PasswordResetScheduler,
      {ConCache,
       [
         name: :app_settings_cache,
         ttl_check_interval: ttl_check,
         global_ttl: global_ttl
       ]},
      Supervisor.child_spec(
        {ConCache,
         [
           name: :tenant_settings_cache,
           ttl_check_interval: tenant_ttl_check,
           global_ttl: tenant_global_ttl
         ]},
        id: :tenant_settings_cache_supervisor
      ),
      # Start a worker by calling: AshPhoenixStarter.Worker.start_link(arg)
      # {AshPhoenixStarter.Worker, arg},
      # Start to serve requests, typically the last entry
      {Phoenix.PubSub, name: AshPhoenixStarter.PubSub},
      AshPhoenixStarterWeb.Presence,
      AshPhoenixStarterWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :ash_phoenix_starter]}
    ]

    children = timezone_resolution_children ++ children

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AshPhoenixStarter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AshPhoenixStarterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
