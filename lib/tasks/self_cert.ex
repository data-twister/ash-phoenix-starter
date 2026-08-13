defmodule Mix.Tasks.AshPhoenixStarter.Gen.Certs do
  use Mix.Task

  @shortdoc "Generates self-signed certificates for local development"
  def run(_args) do
    Mix.Task.run("app.start")
    app_dir = Application.app_dir(:AshPhoenixStarter, "priv/cert")
    AshPhoenixStarter.SelfCertGenerator.generate_self_signed(app_dir)
  end
end
