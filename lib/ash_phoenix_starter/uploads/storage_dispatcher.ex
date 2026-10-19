
defmodule AshPhoenixStarter.Uploads.StorageDispatcher do
  @behaviour Waffle.Storage

  alias AshPhoenixStarter.Settings.Manager

  @impl true
  def put(definition, version, {file, scope}) do
    backend = resolve_backend(scope.team_id)
    backend.put(definition, version, {file, scope})
  end

  @impl true
  def delete(definition, version, {file, scope}) do
    backend = resolve_backend(scope.team_id)
    backend.delete(definition, version, {file, scope})
  end

  @impl true
  def url(definition, version, {file, scope}) do
    backend = resolve_backend(scope.team_id)
    backend.url(definition, version, {file, scope})
  end

  # --- BACKEND RESOLUTION LOGIC ---

  defp resolve_backend(team_id) do
    # Pull the backend type string from ConCache (e.g., "spaces", "r2", "s3", "local")
    provider = Manager.get_tenant(team_id, :storage_provider) || "local"

    case String.downcase(provider) do
      # DigitalOcean Spaces (S3 compatible)
      "spaces" -> Waffle.Storage.S3
      # AWS S3
      "s3" -> Waffle.Storage.S3
      # Cloudflare R2 (Uses S3 compatibility layer)
      "r2" -> Waffle.Storage.S3
      # MinIO (S3 compatible)
      "minio" -> Waffle.Storage.S3
      _ -> Waffle.Storage.Local
    end
  end
end