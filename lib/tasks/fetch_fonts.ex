defmodule Mix.Tasks.FetchFonts do
  use Mix.Task

  @shortdoc "Downloads font files or zip archives from application config, places/extracts them locally, and ensures filenames are lowercase"

  @fonts_dir "priv/static/fonts"

  def run(_args) do
    Mix.shell().info("==> Starting font fetching...")

    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    font_urls = Application.get_env(:AshPhoenixStarter, :font_urls, [])

    if Enum.empty?(font_urls) do
      Mix.shell().error(
        "No font URLs found in application config under :AshPhoenixStarter, :font_urls"
      )
    else
      File.mkdir_p!(@fonts_dir)

      Enum.each(font_urls, fn url ->
        process_url(url)
      end)

      lowercase_all_files_in_dir(@fonts_dir)

      Mix.shell().info("==> All font tasks complete!")
    end
  end

  defp process_url(url) do
    filename =
      case URI.parse(url).path do
        nil ->
          "font.woff2"

        path ->
          name = Path.basename(path)
          if name == "", do: "font.woff2", else: name
      end

    file_path = Path.join(@fonts_dir, filename)

    case download_file(url, file_path) do
      :ok ->
        if String.ends_with?(String.downcase(filename), ".zip") do
          extract_zip(file_path, @fonts_dir)
          # Clean up the zip archive after extraction
          File.rm!(file_path)
        else
          Mix.shell().info("Saved: #{file_path}")
        end

      {:error, reason} ->
        Mix.shell().error("Failed to process #{filename}: #{reason}")
    end
  end

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

  defp extract_zip(zip_path, dest_dir) do
    Mix.shell().info("Extracting #{Path.basename(zip_path)}...")

    case :zip.unzip(String.to_charlist(zip_path), [{:cwd, String.to_charlist(dest_dir)}]) do
      {:ok, _extracted_files} ->
        Mix.shell().info("Successfully extracted #{Path.basename(zip_path)}")

      {:error, reason} ->
        Mix.shell().error("Failed to extract #{Path.basename(zip_path)}: #{inspect(reason)}")
    end
  end

  defp lowercase_all_files_in_dir(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        Enum.each(files, fn file ->
          full_path = Path.join(dir, file)

          if File.regular?(full_path) do
            ext = Path.extname(file)
            basename = Path.basename(file, ext)
            lower_filename = String.downcase(basename) <> String.downcase(ext)
            lower_path = Path.join(dir, lower_filename)

            if full_path != lower_path do
              File.rename!(full_path, lower_path)
              Mix.shell().info("Renamed to lowercase: #{lower_filename}")
            end
          end
        end)

      {:error, reason} ->
        Mix.shell().error("Failed to read fonts directory for lowercase pass: #{inspect(reason)}")
    end
  end
end