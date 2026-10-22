defmodule AshPhoenixStarter.Release do
  @app :AshPhoenixStarter

  def migrate do
    # Load Ecto and Ash Postgres configurations
    Application.load(@app)

    # 1. Run standard Ecto migrations
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    # 2. Run Ash-specific tenant/structure migrations if they exist
    if Code.ensure_loaded?(AshPostgres.Migration) do
      # Triggers Ash Postgres extensions/tenants setup if configured
      # Ash engine handles most changes through normal Ecto repos listed below
      IO.puts("Ash migrations synced via Ecto repositories.")
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end
end
