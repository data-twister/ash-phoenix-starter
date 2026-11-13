defmodule Mix.Tasks.AshPhoenixStarter.Version do
  @moduledoc """
  Bumps the semantic version stored in the `VERSION` file (defaulting to `0.1.0`)
  and creates a Git commit for the release.

  ## Usage

      mix ash_phoenix_starter.version patch
      mix ash_phoenix_starter.version minor
      mix ash_phoenix_starter.version major
  """
  @shortdoc "Updates AshPhoenixStarter's version"

  use Mix.Task

  @version_file "VERSION"
  @default_version "0.1.0"

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run([level]) when level in ["patch", "minor", "major"] do
    current_version = read_current_version()

    new_version_number =
      current_version
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)
      |> bump_hex_version(level)

    File.write!(@version_file, new_version_number <> "\n")
    Mix.shell().info("Bumped version: #{current_version} -> #{new_version_number}")

    {add_out, 0} = System.cmd("git", ["add", @version_file])
    if add_out != "", do: Mix.shell().info(String.trim(add_out))

    {commit_out, 0} = System.cmd("git", ["commit", "-m", "Bump version to #{new_version_number}"])
    Mix.shell().info(String.trim(commit_out))

    :ok
  end

  def run(_args) do
    Mix.raise("Usage: mix ash_phoenix_starter.version [patch | minor | major]")
  end

  @spec read_current_version() :: String.t()
  defp read_current_version do
    case File.read(@version_file) do
      {:ok, content} ->
        case String.trim(content) do
          "" -> @default_version
          version -> version
        end

      {:error, _reason} ->
        @default_version
    end
  end

  @spec bump_hex_version([non_neg_integer()], String.t()) :: String.t()
  defp bump_hex_version([major, minor, patch], "patch"), do: "#{major}.#{minor}.#{patch + 1}"
  defp bump_hex_version([major, minor, _patch], "minor"), do: "#{major}.#{minor + 1}.0"
  defp bump_hex_version([major, _minor, _patch], "major"), do: "#{major + 1}.0.0"
end
