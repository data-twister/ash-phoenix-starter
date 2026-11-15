defmodule AshPhoenixStarter.Uploads.StorageDispatcher do
  @moduledoc """
  Unified storage router for both standard object uploads (`ImageUploader`, `FileAsset`)
  and resumable chunked uploads (`Tussle`).

  Inspects global settings (`Manager.get(:image_mode)`) and per-tenant configuration
  (`TenantConfig`) to route operations to either local filesystem storage
  (`priv/static/...`) or the tenant's S3-compatible bucket via `ExAws.S3`.

  ## Usage Examples

  ### Direct Object Storage

      scope = %{organization_id: org.id}

      # Upload from a file path on disk
      {:ok, "uploads/organizations/123/general/logo.png"} =
        StorageDispatcher.put(
          "uploads/organizations/123/general/logo.png",
          {:path, "/tmp/logo.png"},
          scope
        )

      # Upload from an in-memory binary
      {:ok, "uploads/organizations/123/general/notes.txt"} =
        StorageDispatcher.put(
          "uploads/organizations/123/general/notes.txt",
          "hello world",
          scope,
          content_type: "text/plain"
        )

      # Resolve public URL & delete object
      url = StorageDispatcher.url("uploads/organizations/123/general/logo.png", scope)
      :ok = StorageDispatcher.delete("uploads/organizations/123/general/logo.png", scope)

  ### Tussle Chunked Upload Integration

  Configure `StorageDispatcher` as the storage module in your Tus controller/plug:

      plug Tussle, storage: AshPhoenixStarter.Uploads.StorageDispatcher
  """

  alias AshPhoenixStarter.Settings.Manager
  alias AshPhoenixStarter.Uploads.TenantConfig

  @local_root "priv/static"

  # ============================================================================
  # STANDARD OBJECT STORAGE
  # ============================================================================

  @doc """
  Stores an object at `object_key` using either a `{:path, file_path}` stream
  or a raw binary payload.

  ## Options

  * `:content_type` — Explicit MIME type (defaults to `MIME.from_path(object_key)`)
  * `:acl` — S3 ACL atom (defaults to `:public_read`)
  """
  @spec put(String.t(), {:path, String.t()} | binary(), map(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def put(object_key, binary_or_path, scope, opts \\ []) do
    org_id = extract_org_id(scope)
    clean_key = String.trim_leading(object_key, "/")

    case resolve_backend(org_id) do
      :s3 -> put_s3(org_id, clean_key, binary_or_path, opts)
      :local -> put_local(clean_key, binary_or_path)
    end
  end

  @doc """
  Deletes the object at `object_key` from the resolved backend for `scope`.
  Returns `:ok` even if a local file does not exist (`:enoent`).
  """
  @spec delete(String.t(), map()) :: :ok | {:error, term()}
  def delete(object_key, scope) do
    org_id = extract_org_id(scope)
    clean_key = String.trim_leading(object_key, "/")

    case resolve_backend(org_id) do
      :s3 ->
        bucket = TenantConfig.bucket(org_id)
        aws_cfg = TenantConfig.ex_aws_config(org_id)

        case ExAws.S3.delete_object(bucket, clean_key) |> ExAws.request(aws_cfg) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end

      :local ->
        local_path = Path.join(@local_root, clean_key)

        case File.rm(local_path) do
          :ok -> :ok
          {:error, :enoent} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Resolves the public URL (CDN, S3 bucket URL, or `/uploads/...` local path)
  for `object_key` under `scope`.
  """
  @spec url(String.t(), map()) :: String.t()
  def url(object_key, scope) do
    org_id = extract_org_id(scope)
    clean_key = String.trim_leading(object_key, "/")

    case resolve_backend(org_id) do
      :s3 -> TenantConfig.public_url(org_id, clean_key)
      :local -> "/#{clean_key}"
    end
  end

  # ============================================================================
  # TUSSLE STORAGE CALLBACKS
  # ============================================================================

  @doc """
  Initializes a new resumable Tus upload in either `Tussle.Storage.S3` or
  `Tussle.Storage.Local` based on the tenant's storage provider.
  """
  def create(file, config) when is_map(config) do
    org_id = resolve_org_id(file, config)
    backend = resolve_tus_backend(org_id)
    backend.create(file, prepare_tus_config(backend, org_id, config))
  end

  @doc """
  Appends a binary chunk to an in-progress Tus upload.
  """
  def append(file, config, body) when is_map(config) do
    org_id = resolve_org_id(file, config)
    backend = resolve_tus_backend(org_id)
    backend.append(file, prepare_tus_config(backend, org_id, config), body)
  end

  @doc """
  Finalizes a multipart/chunked Tus upload once all bytes have been received.
  """
  def complete_upload(file, config) when is_map(config) do
    org_id = resolve_org_id(file, config)
    backend = resolve_tus_backend(org_id)
    backend.complete_upload(file, prepare_tus_config(backend, org_id, config))
  end

  @doc """
  Terminates and deletes an in-progress or completed Tus upload.
  """
  def delete(file, config) when is_map(config) do
    org_id = resolve_org_id(file, config)
    backend = resolve_tus_backend(org_id)
    backend.delete(file, prepare_tus_config(backend, org_id, config))
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp put_s3(org_id, clean_key, {:path, file_path}, opts) do
    bucket = TenantConfig.bucket(org_id)
    aws_cfg = TenantConfig.ex_aws_config(org_id)
    s3_opts = build_s3_put_opts(clean_key, opts)

    file_path
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(bucket, clean_key, s3_opts)
    |> ExAws.request(aws_cfg)
    |> case do
      {:ok, _} -> {:ok, clean_key}
      {:error, reason} -> {:error, reason}
    end
  end

  defp put_s3(org_id, clean_key, binary, opts) when is_binary(binary) do
    bucket = TenantConfig.bucket(org_id)
    aws_cfg = TenantConfig.ex_aws_config(org_id)
    s3_opts = build_s3_put_opts(clean_key, opts)

    ExAws.S3.put_object(bucket, clean_key, binary, s3_opts)
    |> ExAws.request(aws_cfg)
    |> case do
      {:ok, _} -> {:ok, clean_key}
      {:error, reason} -> {:error, reason}
    end
  end

  defp put_local(clean_key, {:path, source_path}) do
    dest_path = Path.join(@local_root, clean_key)
    File.mkdir_p!(Path.dirname(dest_path))

    case File.cp(source_path, dest_path) do
      :ok -> {:ok, clean_key}
      {:error, reason} -> {:error, reason}
    end
  end

  defp put_local(clean_key, binary) when is_binary(binary) do
    dest_path = Path.join(@local_root, clean_key)
    File.mkdir_p!(Path.dirname(dest_path))

    case File.write(dest_path, binary) do
      :ok -> {:ok, clean_key}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_s3_put_opts(key, opts) do
    content_type = Keyword.get_lazy(opts, :content_type, fn -> MIME.from_path(key) end)
    acl = Keyword.get(opts, :acl, :public_read)
    [content_type: content_type, acl: acl]
  end

  defp resolve_backend(org_id) do
    if Manager.get(:image_mode) == :local do
      :local
    else
      if TenantConfig.s3_provider?(org_id), do: :s3, else: :local
    end
  end

  defp resolve_tus_backend(org_id) do
    if TenantConfig.s3_provider?(org_id), do: Tussle.Storage.S3, else: Tussle.Storage.Local
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
    Map.get(config, :organization_id) || get_in(file, [:metadata, "organization_id"])
  end

  defp extract_org_id(%{organization_id: org_id}), do: org_id
  defp extract_org_id(_), do: nil
end
