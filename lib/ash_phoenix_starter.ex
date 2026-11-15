defmodule AshPhoenixStarter do
  @moduledoc """
  AshPhoenixStarter keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  # cache the app_version during build time
  @version Mix.Project.config()[:version]
  @description Mix.Project.config()[:description]
  @source_url Mix.Project.config()[:source_url]
  @app Mix.Project.config()[:app]

  defp app_name do
    @app
    |> Atom.to_string()
    |> Macro.camelize()
  end
  def description, do: @description
  def version, do: @version
  def source_url, do: @source_url
end
