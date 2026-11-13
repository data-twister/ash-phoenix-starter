defmodule Mix.Tasks.FetchFonts do
  @moduledoc """
  Downloads configured font files or archives and generates matching `@font-face` CSS rules.

  ## Usage

      mix fetch_fonts
      mix fetch_fonts --if-missing

  ### Command-Line Options

    * `--if-missing` - Skips downloading and CSS generation if the target CSS file
      and all configured font files already exist in `:font_dir`.

  ## Configuration

  Configure the task under the `:ash_phoenix_starter` key in `config/config.exs`:

      config :ash_phoenix_starter,
        font_dir: "priv/static/fonts",
        font_css_path: "assets/css/fonts.css",
        # Optional: inferred automatically from :font_dir if omitted
        font_url_prefix: "/fonts",
        fonts: [
          %{
            family: "Roboto",
            weight: "100 900",
            style: "normal",
            url: "https://jsdelivr.net",
            filename: "roboto-variable-normal.woff2"
          },
          %{
            family: "Roboto",
            weight: "100 900",
            style: "italic",
            url: "https://jsdelivr.net",
            filename: "roboto-variable-italic.woff2"
          }
        ]

  ### Configuration Keys

    * `:font_dir` - Directory where downloaded fonts are saved. Defaults to `"priv/static/fonts"`.
      * Use `"priv/static/fonts"` to serve fonts directly as static assets.
      * Use `"assets/fonts"` to let Tailwind or esbuild bundle and digest them.
    * `:font_css_path` - File path where the generated `@font-face` CSS rules are written.
      Defaults to `"assets/css/fonts.css"`.
    * `:font_url_prefix` - *(Optional)* URL prefix used inside CSS `src: url(...)` declarations.
      If omitted, it defaults to `"/fonts"` for `"priv/static/..."` directories and `"../fonts"`
      for `"assets/..."` directories.
    * `:fonts` - Required list of font maps to download. Each map accepts:
      * `:family` - *(Required)* The `font-family` name used in CSS (e.g., `"Roboto"`).
      * `:weight` - *(Required)* Font weight value or variable range (e.g., `400` or `"100 900"`).
      * `:style` - *(Required)* Font style (e.g., `"normal"` or `"italic"`).
      * `:url` - *(Required)* Direct URL to a `.woff2`, `.woff`, `.ttf`, `.otf`, or `.zip` file.
      * `:filename` - *(Optional)* Local filename to save as. Automatically lowercased.
        Falls back to the URL basename if omitted.

  ## Mix Alias Integration

  Add `fetch_fonts --if-missing` to your `assets.setup` alias in `mix.exs`:

      defp aliases do
        [
          "assets.setup": [
            "tailwind.install --if-missing",
            "esbuild.install --if-missing",
            "fetch_fonts --if-missing"
          ]
        ]
      end
  """

  use Mix.Task

  @shortdoc "Downloads configured fonts to a configurable directory and generates @font-face CSS"

  @type font_config :: %{
          required(:family) => String.t(),
          required(:weight) => integer() | String.t(),
          required(:style) => String.t(),
          required(:url) => String.t(),
          optional(:filename) => String.t()
        }

  @type processed_font :: %{
          required(:family) => String.t(),
          required(:weight) => integer() | String.t(),
          required(:style) => String.t(),
          required(:url) => String.t(),
          required(:resolved_filename) => String.t(),
          optional(:filename) => String.t()
        }

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    fonts = Application.get_env(:ash_phoenix_starter, :fonts, [])
    fonts_dir = Application.get_env(:ash_phoenix_starter, :font_dir, "priv/static/fonts")
    css_path = Application.get_env(:ash_phoenix_starter, :font_css_path, "assets/css/fonts.css")

    url_prefix =
      Application.get_env(
        :ash_phoenix_starter,
        :font_url_prefix,
        default_url_prefix(fonts_dir)
      )

    if "--if-missing" in args and all_files_present?(fonts, fonts_dir, css_path) do
      Mix.shell().info("==> Fonts in #{fonts_dir} and CSS already exist, skipping download.")
    else
      Mix.shell().info("==> Starting font fetching into #{fonts_dir}...")
      Application.ensure_all_started(:inets)
      Application.ensure_all_started(:ssl)

      if Enum.empty?(fonts) do
        Mix.shell().error("No fonts found in config under :ash_phoenix_starter, :fonts")
      else
        File.mkdir_p!(fonts_dir)

        downloaded_fonts =
          Enum.flat_map(fonts, fn font ->
            case process_font(font, fonts_dir) do
              {:ok, processed_font} -> [processed_font]
              :error -> []
            end
          end)

        lowercase_all_files_in_dir(fonts_dir)
        generate_css(downloaded_fonts, css_path, url_prefix)
        Mix.shell().info("==> All font tasks complete!")
      end
    end

    :ok
  end

  @spec default_url_prefix(String.t()) :: String.t()
  defp default_url_prefix("priv/static/" <> rest), do: "/" <> String.trim_trailing(rest, "/")
  defp default_url_prefix("assets/" <> rest), do: "../" <> String.trim_trailing(rest, "/")
  defp default_url_prefix(_), do: "/fonts"

  @spec all_files_present?([font_config()], Path.t(), Path.t()) :: boolean()
  defp all_files_present?(fonts, fonts_dir, css_path) do
    fonts != [] and
      File.exists?(css_path) and
      Enum.all?(fonts, fn font ->
        filename = resolve_filename(font) |> String.downcase()
        File.exists?(Path.join(fonts_dir, filename))
      end)
  end

  @spec process_font(font_config(), Path.t()) :: {:ok, processed_font()} | :error
  defp process_font(font, fonts_dir) do
    filename = resolve_filename(font) |> String.downcase()
    file_path = Path.join(fonts_dir, filename)

    case download_file(font.url, file_path) do
      :ok ->
        if String.ends_with?(filename, ".zip") do
          extract_zip(file_path, fonts_dir)
          File.rm!(file_path)
        else
          Mix.shell().info("Saved: #{file_path}")
        end

        {:ok, Map.put(font, :resolved_filename, filename)}

      {:error, reason} ->
        Mix.shell().error("Failed to process #{filename}: #{reason}")
        :error
    end
  end

  @spec resolve_filename(font_config()) :: String.t()
  defp resolve_filename(%{filename: filename}) when is_binary(filename) and filename != "",
    do: filename

  defp resolve_filename(%{url: url}) do
    case URI.parse(url).path do
      nil -> "font.woff2"
      path -> if Path.basename(path) == "", do: "font.woff2", else: Path.basename(path)
    end
  end

  @spec download_file(String.t(), Path.t()) :: :ok | {:error, String.t()}
  defp download_file(url, dest_path) do
    Mix.shell().info("Downloading #{Path.basename(dest_path)} from #{url}...")

    case :httpc.request(:get, {String.to_charlist(url), []}, [], [{:body_format, :binary}]) do
      {:ok, {{_version, 200, _status}, _headers, body}} ->
        File.write!(dest_path, body)
        :ok

      {:ok, {{_version, status, _status}, _headers, _body}} ->
        {:error, "HTTP status #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  @spec extract_zip(Path.t(), Path.t()) :: :ok
  defp extract_zip(zip_path, dest_dir) do
    Mix.shell().info("Extracting #{Path.basename(zip_path)}...")

    case :zip.unzip(String.to_charlist(zip_path), [{:cwd, String.to_charlist(dest_dir)}]) do
      {:ok, _extracted_files} ->
        Mix.shell().info("Successfully extracted #{Path.basename(zip_path)}")

      {:error, reason} ->
        Mix.shell().error("Failed to extract #{Path.basename(zip_path)}: #{inspect(reason)}")
    end

    :ok
  end

  @spec lowercase_all_files_in_dir(Path.t()) :: :ok
  defp lowercase_all_files_in_dir(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        Enum.each(files, fn file ->
          full_path = Path.join(dir, file)

          if File.regular?(full_path) do
            lower_filename = String.downcase(file)
            lower_path = Path.join(dir, lower_filename)

            if full_path != lower_path do
              File.rename!(full_path, lower_path)
              Mix.shell().info("Renamed to lowercase: #{lower_filename}")
            end
          end
        end)

      {:error, reason} ->
        Mix.shell().error("Failed to read fonts directory: #{inspect(reason)}")
    end

    :ok
  end

  @spec generate_css([processed_font()], Path.t(), String.t()) :: :ok
  defp generate_css(fonts, css_path, url_prefix) do
    File.mkdir_p!(Path.dirname(css_path))

    clean_prefix = String.trim_trailing(url_prefix, "/")
    header = "/* Auto-generated by mix fetch_fonts. Do not edit manually. */\n\n"

    rules =
      Enum.map_join(fonts, "\n\n", fn font ->
        format = font_format(font.resolved_filename)

        """
        @font-face {
          font-family: "#{font.family}";
          font-style: #{font.style};
          font-weight: #{font.weight};
          font-display: swap;
          src: url("#{clean_prefix}/#{font.resolved_filename}") format("#{format}");
        }
        """
        |> String.trim()
      end)

    File.write!(css_path, header <> rules <> "\n")
    Mix.shell().info("Generated @font-face CSS at: #{css_path}")
    :ok
  end

  @spec font_format(String.t()) :: String.t()
  defp font_format(filename) do
    case Path.extname(filename) do
      ".woff2" -> "woff2"
      ".woff" -> "woff"
      ".ttf" -> "truetype"
      ".otf" -> "opentype"
      _ -> "woff2"
    end
  end
end
