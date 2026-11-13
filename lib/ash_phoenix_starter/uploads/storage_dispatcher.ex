defmodule AshPhoenixStarter.Uploads.StorageDispatcher do
  @behaviour Waffle.Storage

  alias AshPhoenixStarter.Settings.Manager
  alias AshPhoenixStarter.Uploads.TenantConfig

  @s3_providers ["spaces", "s3", "r2", "minio"]

  # ============================================================================
  # WAFFLE STORAGE CALLBACKS
  # ============================================================================

  @impl Waffle.Storage
  def put(definition, version, {file, scope}) do
    org_id = extract_org_id(scope)
    resolve_waffle_backend(org_id).put(definition, version, {file, scope})
  end

  @impl Waffle.Storage
  def delete(definition, version, {file, scope}) do
    org_id = extract_org_id(scope)
    resolve_waffle_backend(org_id).delete(definition, version, {file, scope})
  end

  @impl Waffle.Storage
  def url(definition, version, {file, scope}) do
    org_id = extract_org_id(scope)
    resolve_waffle_backend(org_id).url(definition, version, {file, scope})
  end

  def url(definition, version, {file, scope}, options) do
    org_id = extract_org_id(scope)
    backend = resolve_waffle_backend(org_id)

    if function_exported?(backend, :url, 4) do
      backend.url(definition, version, {file, scope}, options)
    else
      backend.url(definition, version, {file, scope})
    end
  end

  # ============================================================================
  # TUSSLE STORAGE CALLBACKS
  # ============================================================================

  def create(file, config) when is_map(config) do
    org_id = resolve_org_id(file, config)
    backend = resolve_tus_backend(org_id)
    backend.create(file, prepare_tus_config(backend, org_id, config))
  end

  def append(file, config, body) when is_map(config) do
    org_id = resolve_org_id(file, config)
    backend = resolve_tus_backend(org_id)
    backend.append(file, prepare_tus_config(backend, org_id, config), body)
  end

  def complete_upload(file, config) when is_map(config) do
    org_id = resolve_org_id(file, config)
    backend = resolve_tus_backend(org_id)
    backend.complete_upload(file, prepare_tus_config(backend, org_id, config))
  end

  def delete(file, config) when is_map(config) do
    org_id = resolve_org_id(file, config)
    backend = resolve_tus_backend(org_id)
    backend.delete(file, prepare_tus_config(backend, org_id, config))
  end

  # ============================================================================
  # BACKEND RESOLUTION & CONFIG HELPERS
  # ============================================================================

  defp resolve_waffle_backend(organization_id) do
    if Manager.get(:image_mode) == :local do
      Waffle.Storage.Local
    else
      case TenantConfig.provider(organization_id) do
        p when p in @s3_providers -> Waffle.Storage.S3
        _ -> Waffle.Storage.Local
      end
    end
  end

  defp resolve_tus_backend(organization_id) do
    case TenantConfig.provider(organization_id) do
      p when p in @s3_providers -> Tussle.Storage.S3
      _ -> Tussle.Storage.Local
    end
  end

  defp prepare_tus_config(Tussle.Storage.S3, org_id, config) do
    prefix = if org_id, do: "uploads/organizations/#{org_id}/tus", else: "uploads/tus"

    config
    |> Map.put(:organization_id, org_id)
    |> Map.put_new(:s3_prefix, prefix)
  end

  defp prepare_tus_config(Tussle.Storage.Local, org_id, config) do
    default_dir =
      if org_id do
        "priv/static/uploads/organizations/#{org_id}/tus"
      else
        "priv/static/uploads/tus"
      end

    Map.put(config, :base_path, default_dir)
  end

  defp resolve_org_id(file, config) do
    Map.get(config, :organization_id) ||
      get_in(file, [:metadata, "organization_id"])
  end

  defp extract_org_id(%{organization_id: org_id}), do: org_id
  defp extract_org_id(_), do: nil
end
