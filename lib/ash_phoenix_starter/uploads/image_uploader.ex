defmodule AshPhoenixStarter.Uploads.ImageUploader do
  @moduledoc """
  Handles image validation, thumbnail generation via ImageMagick,
  and multi-version storage via `StorageDispatcher`.
  """

  alias AshPhoenixStarter.Settings.Manager
  alias AshPhoenixStarter.Uploads.StorageDispatcher

  @extensions ~w(jpg jpeg png webp)
  @default_max_size 500 * 1024 * 1024

  @type file_input :: %{
          required(:file_name) => String.t(),
          optional(:path) => String.t(),
          optional(:binary) => binary()
        }

  @type scope :: %{
          required(:type) => atom(),
          optional(:organization_id) => String.t() | nil
        }

  @doc """
  Validates, generates `:original` and `:thumb` versions, and uploads both.
  Returns `{:ok, base_filename}` (e.g. `"avatar.png"`) to store on your Ash attribute.
  """
  @spec store(file_input(), scope()) :: {:ok, String.t()} | {:error, term()}
  def store(file, scope) do
    with :ok <- validate(file),
         {:ok, source_path, cleanup?} <- ensure_temp_file(file),
         {:ok, thumb_path} <- generate_thumbnail(source_path) do
      try do
        original_key = object_key(:original, file.file_name, scope)
        thumb_key = object_key(:thumb, file.file_name, scope)

        with {:ok, _} <- StorageDispatcher.put(original_key, {:path, source_path}, scope),
             {:ok, _} <- StorageDispatcher.put(thumb_key, {:path, thumb_path}, scope) do
          {:ok, Path.basename(file.file_name)}
        end
      after
        File.rm(thumb_path)
        if cleanup?, do: File.rm(source_path)
      end
    end
  end

  @doc """
  Deletes both `:original` and `:thumb` versions from storage.
  """
  @spec delete(String.t() | nil, scope()) :: :ok
  def delete(nil, _scope), do: :ok

  def delete(file_name, scope) when is_binary(file_name) do
    StorageDispatcher.delete(object_key(:original, file_name, scope), scope)
    StorageDispatcher.delete(object_key(:thumb, file_name, scope), scope)
    :ok
  end

  @doc """
  Resolves the public URL for `:original` or `:thumb`.
  """
  @spec url(String.t() | nil, scope(), :original | :thumb) :: String.t() | nil
  def url(file_name, scope, version \\ :original)
  def url(nil, _scope, _version), do: nil

  def url(file_name, scope, version) when version in [:original, :thumb] do
    key = object_key(version, file_name, scope)
    StorageDispatcher.url(key, scope)
  end

  @doc """
  Builds the relative storage key matching your previous Waffle directory layout.
  """
  @spec object_key(:original | :thumb, String.t(), scope()) :: String.t()
  def object_key(version, file_name, scope) do
    dir = storage_dir(scope) |> String.trim("/")
    stem = Path.basename(file_name, Path.extname(file_name))

    filename =
      case version do
        :original -> "#{stem}#{Path.extname(file_name)}"
        :thumb -> "#{stem}_thumb.jpg"
      end

    "#{dir}/#{filename}"
  end

  def storage_dir(scope) do
    case scope.type do
      :service -> "uploads/service"
      :feature -> "uploads/feature"
      _ -> "uploads/organizations/#{scope.organization_id}/#{scope.type}"
    end
  end

  # ============================================================================
  # VALIDATION & IMAGE PROCESSING
  # ============================================================================

  def validate(file) do
    cond do
      not valid_extension?(file) -> {:error, :invalid_extension}
      not valid_file_size?(file) -> {:error, :file_too_large}
      true -> :ok
    end
  end

  defp valid_extension?(%{file_name: file_name}) do
    file_name
    |> Path.extname()
    |> String.downcase()
    |> String.trim_leading(".")
    |> then(&(&1 in @extensions))
  end

  defp valid_file_size?(file) do
    max_size = Manager.get(:max_upload_size) || @default_max_size

    case get_file_size(file) do
      {:ok, size} -> size <= max_size
      :error -> false
    end
  end

  defp get_file_size(%{binary: binary}) when is_binary(binary), do: {:ok, byte_size(binary)}

  defp get_file_size(%{path: path}) when is_binary(path) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size}} -> {:ok, size}
      {:error, _} -> :error
    end
  end

  defp get_file_size(_), do: :error

  defp ensure_temp_file(%{path: path}) when is_binary(path), do: {:ok, path, false}

  defp ensure_temp_file(%{binary: binary, file_name: file_name}) when is_binary(binary) do
    ext = Path.extname(file_name)
    tmp_path = Path.join(System.tmp_dir!(), "upload_#{System.unique_integer([:positive])}#{ext}")

    case File.write(tmp_path, binary) do
      :ok -> {:ok, tmp_path, true}
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_thumbnail(source_path) do
    thumb_path =
      Path.join(System.tmp_dir!(), "thumb_#{System.unique_integer([:positive])}.jpg")

    args = [
      source_path,
      "-thumbnail",
      "300x300^",
      "-gravity",
      "center",
      "-extent",
      "300x300",
      thumb_path
    ]

    case System.cmd("convert", args, stderr_to_stdout: true) do
      {_output, 0} -> {:ok, thumb_path}
      {error, _code} -> {:error, {:imagemagick_failed, error}}
    end
  end
end
