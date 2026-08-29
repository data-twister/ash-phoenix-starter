defmodule AshPhoenixStarter.MixProject do
  use Mix.Project

  def project do
    [
      app: :AshPhoenixStarter,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_paths: ["test", "lib"],
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      consolidate_protocols: Mix.env() != :dev
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {AshPhoenixStarter.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bandit, "~> 1.5"},
      {:bcrypt_elixir, "~> 3.0"},
      {:dns_cluster, "~> 0.2.0"},
      {:ecto_sql, "~> 3.13"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix, "~> 1.8.1"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0", override: true},
      {:phoenix_seo, "~> 0.3.1"},
      {:phoenix_copy, ">= 0.0.0"},
      {:phoenix_iconify, "~> 0.3.2"},
      {:phoenix_live_favicon, "~> 1.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:phoenix_bakery, "~> 0.1.0", runtime: false},
      {:live_debugger, "~> 0.4", only: [:dev]},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:swoosh, "~> 1.16"},
      {:ash, "~> 3.0"},
      {:ash_json_api, "~> 1.0"},
      {:ash_money, "~> 0.2"},
      {:ash_double_entry, "~> 1.0"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:ash_authentication, "~> 4.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_state_machine, "~> 0.2.13"},
      {:ash_rate_limiter, "~> 2.0"},
      {:ash_query_builder, "~> 0.10.0"},
      {:ash_credo, "~> 0.17.1"},
      {:ash_diagram, "~> 0.2.2"},
      {:ash_ops, "~> 0.2"},
      {:ash_oban, "~> 0.8"},
      {:oban, "~> 2.0"},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:ex_cldr, "~> 2.45", override: true},
      {:ex_cldr_calendars, "~> 2.1"},
      {:ex_cldr_units, "~> 3.18"},
      {:ex_cldr_dates_times, "~> 2.0"},
      {:ex_cldr_numbers, "~> 2.32"},
      {:ex_cldr_territories, "~> 2.9"},
      {:ex_cldr_plugs, "~> 1.3"},
      {:ex_cldr_languages, "~> 0.2.0"},
      {:ex_cldr_locale_display, "~> 1.1"},
      {:ex_cldr_units_sql, "~> 1.0"},
      {:ex_cldr_routes, "~> 1.6"},
      {:open_api_spex, "~> 3.0"},
      {:ex_money_sql, "~> 1.0"},
      {:req, "~> 0.5"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:con_cache, "~> 1.1"},
      {:nebulex, "~> 2.5"},
      {:decorator, "~> 1.4"},
      {:rename_project, "~> 0.1"},
      {:x509, "~> 0.8"},
      {:maybe, "~> 1.0"},
      {:hammer, ">= 0.0.0"},
      {:timex, ">= 0.0.0"},
      {:adept_svg, "~> 0.3.1"},
      {:flag_icons, "~> 0.1.0"},
      {:nimble_csv, "~> 1.0"},
      {:cinder, "~> 0.7"},
      {:picosat_elixir, "~> 0.2"},
      {:altcha, github: "data-twister/altcha-lib-ex"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build", "run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ash.setup --quiet", "test"],
      "assets.setup": [
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        "altcha.install"
      ],
      "assets.build": ["compile", "tailwind AshPhoenixStarter", "esbuild AshPhoenixStarter"],
      "assets.deploy": [
        "tailwind AshPhoenixStarter --minify",
        "esbuild AshPhoenixStarter --minify",
        "phx.digest"
      ],
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
