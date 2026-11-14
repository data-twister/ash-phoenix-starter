defmodule Mix.Tasks.AshPhoenixStarter.Version do
  @moduledoc """
  Bumps the semantic version stored in the `VERSION` file (defaulting to `0.1.0`),
  creates a Git commit, and optionally creates an annotated Git tag.

  ## Usage

      mix ash_phoenix_starter.version patch
      mix ash_phoenix_starter.version minor --tag
      mix ash_phoenix_starter.version major -t -f

  ### Options

    * `--tag`, `-t` - Creates an annotated Git tag (e.g., `v0.1.1`) after committing.
    * `--force`, `-f` - Skips the uncommitted changes confirmation prompt.

    mix.exs needs to be modified add at the top after module delcaration
            @version (case File.read("VERSION") do
              {:ok, content} ->
                case String.trim(content) do
                  "" -> "0.1.0"
                  version -> version
                end

              {:error, _} ->
                "0.1.0"
            end) 

    def project do
      [
        version: @version
    end
  """
  @shortdoc "Updates AshPhoenixStarter's version"

  use Mix.Task

  @version_file "VERSION"
  @default_version "0.1.0"

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    {opts, positional, _invalid} =
      OptionParser.parse(args,
        switches: [tag: :boolean, force: :boolean],
        aliases: [t: :tag, f: :force]
      )

    case positional do
      [level] when level in ["patch", "minor", "major"] ->
        ensure_clean_or_confirm!(Keyword.get(opts, :force, false))
        bump_and_commit(level, Keyword.get(opts, :tag, false))

      _ ->
        Mix.raise("Usage: mix ash_phoenix_starter.version [patch | minor | major] [--tag] [--force]")
    end
  end

  @spec ensure_clean_or_confirm!(boolean()) :: :ok
  defp ensure_clean_or_confirm!(true), do: :ok

  defp ensure_clean_or_confirm!(false) do
    case System.cmd("git", ["status", "--porcelain"]) do
      {"", 0} ->
        :ok

      {changes, 0} ->
        Mix.shell().error("Warning: You have uncommitted changes in your working tree:\n")
        Mix.shell().info(String.trim_trailing(changes) <> "\n")

        unless Mix.shell().yes?("Do you want to continue and commit only #{@version_file}?") do
          Mix.raise("Aborted version bump due to uncommitted changes.")
        end

        :ok

      {error_out, _code} ->
        Mix.raise("Failed to check git status: #{String.trim(error_out)}")
    end
  end

  @spec bump_and_commit(String.t(), boolean()) :: :ok
  defp bump_and_commit(level, create_tag?) do
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

    {commit_out, 0} =
      System.cmd("git", ["commit", @version_file, "-m", "Bump version to #{new_version_number}"])

    Mix.shell().info(String.trim(commit_out))

    if create_tag? do
      tag_name = "v#{new_version_number}"
      {_tag_out, 0} = System.cmd("git", ["tag", "-a", tag_name, "-m", "Release #{tag_name}"])
      Mix.shell().info("Created tag: #{tag_name}")
    end

    :ok
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
