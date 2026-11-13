defmodule AshPhoenixStarter.Uploads.ImageUploader do
  use Waffle.Definition
  use Waffle.Ecto.Definition

  alias AshPhoenixStarter.Settings.Manager
  alias AshPhoenixStarter.Uploads.TenantConfig

  @versions [:original, :thumb]
  @extensions ~w(jpg jpeg png webp)
  @default_max_size 500 * 1024 * 1024

  # Point Waffle to our multi-backend dispatcher
  def storage do
    AshPhoenixStarter.Uploads.StorageDispatcher
  end

  # Dynamically pull the correct bucket name from ConCache
  def bucket(_version, {_, scope}) do
    TenantConfig.bucket(scope.organization_id)
  end

  # Dynamically configure ExAws credentials & custom endpoints
  def ex_aws_config({_, scope}) do
    TenantConfig.ex_aws_config(scope.organization_id)
  end

  # Respect global `:image_mode` (:local vs :cdn) before resolving tenant cloud URLs
  def url(version, {_file, scope} = file_scope, options) do
    image_mode = Manager.get(:image_mode) || :cdn

    case {image_mode, TenantConfig.provider(scope.organization_id)} do
      {:local, _} ->
        super(version, file_scope, options)

      {_, p} when p in ["spaces", "s3", "r2", "minio"] ->
        object_key = full_object_key(version, file_scope)
        TenantConfig.public_url(scope.organization_id, object_key)

      _ ->
        super(version, file_scope, options)
    end
  end

  def validate({file, _spec}) do
    valid_extension?(file) and valid_file_size?(file)
  end

  def transform(:thumb, _) do
    {:convert, "-thumbnail 300x300^ -gravity center -extent 300x300", :jpg}
  end

  def filename(:original, {file, _}) do
    Path.basename(file.file_name, Path.extname(file.file_name))
  end

  def filename(:thumb, {file, _}) do
    "#{Path.basename(file.file_name, Path.extname(file.file_name))}_thumb"
  end

  def storage_dir_version_prefix?, do: true

  def storage_dir(_, {_, scope}) do
    case scope.type do
      :service -> "uploads/service/"
      :feature -> "uploads/feature/"
      _ -> "uploads/organizations/#{scope.organization_id}/#{scope.type}"
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp valid_extension?(file) do
    file.file_name
    |> Path.extname()
    |> String.downcase()
    |> String.trim_leading(".")
    |> then(&Enum.member?(@extensions, &1))
  end

  defp valid_file_size?(file) do
    max_size = Manager.get(:max_upload_size) || @default_max_size

    case get_file_size(file) do
      {:ok, size} -> size <= max_size
      :error -> false
    end
  end

  defp get_file_size(%{binary: binary}) when is_binary(binary) do
    {:ok, byte_size(binary)}
  end

  defp get_file_size(%{path: path}) when is_binary(path) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size}} -> {:ok, size}
      {:error, _} -> :error
    end
  end

  defp get_file_size(_), do: :error

  defp full_object_key(version, {file, _scope} = file_scope) do
    dir = storage_dir(version, file_scope) |> String.trim("/")
    ext = if version == :thumb, do: ".jpg", else: Path.extname(file.file_name)
    file_with_ext = "#{filename(version, file_scope)}#{ext}"

    "#{dir}/#{file_with_ext}"
  end
end
