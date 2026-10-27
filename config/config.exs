# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ash_oban, pro?: false

config :ash_phoenix_starter, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [default: 10, system: 10],
  repo: AshPhoenixStarter.Repo,
  plugins: [{Oban.Plugins.Cron, []}]

config :mime,
  extensions: %{"json" => "application/vnd.api+json"},
  types: %{"application/vnd.api+json" => ["json"]}

config :ash_json_api,
  show_public_calculations_when_loaded?: false,
  authorize_update_destroy_with_error?: true

config :ex_cldr, default_backend: AshPhoenixStarter.Cldr
config :cinder, default_theme: "modern"

config :ash,
  allow_forbidden_field_for_relationships_by_default?: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true,
  known_types: [AshMoney.Types.Money],
  custom_types: [money: AshMoney.Types.Money]

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :json_api,
        :account,
        :balance,
        :transfer,
        :authentication,
        :tokens,
        :postgres,
        :resource,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :multitenancy,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [
      section_order: [:json_api, :resources, :policies, :authorization, :domain, :execution]
    ]
  ]

config :ash_phoenix_starter,
  ecto_repos: [AshPhoenixStarter.Repo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [
    AshPhoenixStarter.Core,
    AshPhoenixStarter.Accounts,
    AshPhoenixStarter.Ledger,
    AshPhoenixStarter.Settings
  ]

# Configure super admin users who are allowed to do
# special actions such as impersonating other
# users in the teams. Seeing all teams
# and more...

# Configures the endpoint
config :ash_phoenix_starter, AshPhoenixStarterWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AshPhoenixStarterWeb.ErrorHTML, json: AshPhoenixStarterWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AshPhoenixStarter.PubSub,
  live_view: [signing_salt: "waEAzL0/"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :ash_phoenix_starter, AshPhoenixStarter.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  AshPhoenixStarter: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/svg/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  AshPhoenixStarter: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :phoenix_copy,
  images: [
    source: Path.expand("../assets/images/", __DIR__),
    destination: Path.expand("../priv/static/images/", __DIR__)
  ],
  fonts: [
    source: Path.expand("../assets/fonts/", __DIR__),
    destination: Path.expand("../priv/static/fonts/", __DIR__)
  ]

# config :phoenix,
#  static_compressors: [
#    PhoenixBakery.Gzip,
#    PhoenixBakery.Zstd
#  ]

config :mime, :types, %{
  "application/jrd+json" => ["jrd"]
}

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

config :ash_phoenix_starter, :global_cache_config,
  ttl_check_interval: :timer.seconds(120),
  global_ttl: :timer.minutes(60)

config :ash_phoenix_starter, :tenant_cache_config,
  ttl_check_interval: :timer.seconds(30),
  global_ttl: :timer.minutes(15)

config :ex_aws,
  access_key_id: System.get_env("SPACES_ACCESS_KEY"),
  secret_access_key: System.get_env("SPACES_SECRET_KEY"),
  # ExAws requires a region string, but you override the host below
  region: "us-east-1"

config :ex_aws, :s3,
  scheme: "https://",
  host: System.get_env("SPACES_HOST") || "nyc3.digitaloceanspaces.com",
  port: 443

config :waffle, storage: Waffle.Storage.Local

config :ash_phoenix_starter, :timezone_cache_config,
  ttl_check_interval: 3600,
  global_ttl: 86400

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
