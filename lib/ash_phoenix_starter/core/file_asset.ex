defmodule AshPhoenixStarter.Core.FileAsset do
  defmodule AshPhoenixStarter.Core.FileAsset do
  @moduledoc """
  Manages uploaded file assets and their backing storage objects across
  per-tenant S3-compatible providers (AWS S3, Cloudflare R2, DigitalOcean Spaces, MinIO)
  and local disk storage.

  ## Features

  * **Atomic Upload & Record Creation:** `FileAsset.upload/2` validates the file,
    generates `:original` and `:thumb` versions via `ImageUploader`, uploads them
    through `StorageDispatcher`, and persists the `FileAsset` record.
  * **Automatic Rollback:** If the database insert fails, uploaded remote/local
    objects are automatically deleted so no orphaned files remain.
  * **Cascading Deletion:** Destroying a `FileAsset` via `FileAsset.destroy/1`
    deletes both the original file and its `_thumb.jpg` variant (or the Tus
    chunked upload object).

  ## Examples

  ### 1. Uploading from In-Memory Binary Data

  Useful for background jobs, webhooks, base64 payloads, or generated images:

      {:ok, binary} = File.read("/tmp/logo.png")

      {:ok, asset} =
        AshPhoenixStarter.Core.FileAsset.upload(
          %{
            file_name: "logo.png",
            binary: binary,
            content_type: "image/png"
          },
          %{organization_id: org.id, type: :general}
        )

  ### 2. Uploading from a Local File Path (Without `consume_uploaded_entries`)

  Useful for `Plug.Upload` structs in standard Phoenix controllers, Mix tasks,
  or seed scripts where the file is already on disk:

      # Example with a %Plug.Upload{} from a controller action:
      def create(conn, %{"file" => %Plug.Upload{} = upload}) do
        file_input = %{
          file_name: upload.filename,
          path: upload.path,
          content_type: upload.content_type
        }

        case AshPhoenixStarter.Core.FileAsset.upload(file_input, %{organization_id: conn.assigns.org_id}) do
          {:ok, asset} -> json(conn, %{id: asset.id, url: asset.file_url})
          {:error, reason} -> conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
        end
      end

      # Or directly from any file path on disk:
      {:ok, asset} =
        AshPhoenixStarter.Core.FileAsset.upload(
          %{file_name: "banner.webp", path: "/var/tmp/banner.webp"},
          %{organization_id: org.id}
        )

  ### 3. Uploading from Phoenix LiveView (`consume_uploaded_entries/3`)

      uploaded_assets =
        consume_uploaded_entries(socket, :photos, fn %{path: path}, entry ->
          file_input = %{
            file_name: entry.client_name,
            path: path,
            content_type: entry.client_type
          }

          case AshPhoenixStarter.Core.FileAsset.upload(file_input, %{organization_id: org.id}) do
            {:ok, asset} -> {:ok, asset}
            {:error, reason} -> {:postpone, reason}
          end
        end)

  ### 4. Resolving Original & Thumbnail URLs

      asset = Ash.load!(asset, :thumb_url)

      asset.file_url
      # => "https://example.com<org_id>/general/logo.png"

      asset.thumb_url
      # => "https://example.com<org_id>/general/logo_thumb.jpg"

  ### 5. Deleting an Asset and Its Remote Files

      :ok = AshPhoenixStarter.Core.FileAsset.destroy(asset)
  """

  use Ash.Resource,
    domain: AshPhoenixStarter.Core,
    data_layer: AshPostgres.DataLayer

  alias AshPhoenixStarter.Uploads.{ImageUploader, StorageDispatcher, TenantConfig}

  postgres do
    table "file_assets"
    repo AshPhoenixStarter.Repo
  end

  code_interface do
    define :read, action: :read
    define :list, action: :read
    define :create, action: :create
    define :upload, action: :upload, args: [:file]
    define :destroy, action: :destroy
  end

  actions do
    defaults [:read]

    create :create do
      accept [:filename, :file_url, :file_size, :content_type, :organization_id, :type]
    end

    create :upload do
      accept [:organization_id, :type]

      argument :file, :map do
        allow_nil? false
        description "Map containing :file_name and either :path or :binary"
      end

      change fn changeset, _context ->
        Ash.Changeset.before_action(changeset, fn changeset ->
          file = Ash.Changeset.get_argument(changeset, :file)
          org_id = Ash.Changeset.get_attribute(changeset, :organization_id)
          type = Ash.Changeset.get_attribute(changeset, :type) || :general
          scope = %{organization_id: org_id, type: type}

          case ImageUploader.store(file, scope) do
            {:ok, stored_filename} ->
              file_url = ImageUploader.url(stored_filename, scope, :original)

              changeset
              |> Ash.Changeset.force_change_attribute(:filename, stored_filename)
              |> Ash.Changeset.force_change_attribute(:file_url, file_url)
              |> Ash.Changeset.force_change_attribute(:file_size, detect_file_size(file))
              |> Ash.Changeset.force_change_attribute(:content_type, detect_content_type(file))

            {:error, reason} ->
              Ash.Changeset.add_error(changeset,
                field: :file,
                message: format_upload_error(reason)
              )
          end
        end)
      end

      # Clean up uploaded remote files if the database insert fails
      change after_transaction(fn
               _changeset, {:ok, record}, _context ->
                 {:ok, record}

               changeset, {:error, error}, _context ->
                 rollback_uploaded_file(changeset)
                 {:error, error}
             end)
    end

    destroy :destroy do
      primary? true

      change after_transaction(fn
               _changeset, {:ok, record}, _context ->
                 delete_remote_files(record)
                 {:ok, record}

               _changeset, {:error, error}, _context ->
                 {:error, error}
             end)
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :filename, :string, allow_nil?: false, public?: true
    attribute :file_url, :string, allow_nil?: false, public?: true
    attribute :file_size, :integer, public?: true
    attribute :content_type, :string, public?: true
    attribute :organization_id, :uuid, allow_nil?: true, public?: true

    attribute :type, :atom do
      constraints one_of: [:general]
      default :general
      allow_nil? false
      public? true
    end

    timestamps()
  end

  calculations do
    calculate :thumb_url, :string, fn records, _context ->
      Enum.map(records, &derive_thumb_url/1)
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp detect_file_size(%{binary: binary}) when is_binary(binary), do: byte_size(binary)

  defp detect_file_size(%{path: path}) when is_binary(path) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size}} -> size
      _ -> nil
    end
  end

  defp detect_file_size(_), do: nil

  defp detect_content_type(%{content_type: ct}) when is_binary(ct) and ct != "", do: ct
  defp detect_content_type(%{file_name: file_name}), do: MIME.from_path(file_name)
  defp detect_content_type(_), do: "application/octet-stream"

  defp format_upload_error(:invalid_extension), do: "Unsupported file format"
  defp format_upload_error(:file_too_large), do: "File exceeds maximum allowed size"
  defp format_upload_error({:imagemagick_failed, _}), do: "Failed to process image thumbnail"
  defp format_upload_error(reason), do: "Upload failed: #{inspect(reason)}"

  defp rollback_uploaded_file(changeset) do
    filename = Ash.Changeset.get_attribute(changeset, :filename)
    org_id = Ash.Changeset.get_attribute(changeset, :organization_id)
    type = Ash.Changeset.get_attribute(changeset, :type) || :general

    if is_binary(filename) do
      ImageUploader.delete(filename, %{organization_id: org_id, type: type})
    end
  end

  defp delete_remote_files(%__MODULE__{file_url: file_url, organization_id: org_id}) do
    object_key = extract_object_key(file_url, org_id)
    scope = %{organization_id: org_id}

    StorageDispatcher.delete(object_key, scope)

    unless tus_upload?(object_key) do
      case sibling_variant_key(object_key) do
        nil -> :ok
        sibling_key -> StorageDispatcher.delete(sibling_key, scope)
      end
    end
  end

  defp tus_upload?(object_key) do
    String.contains?(object_key, "/tus/") or String.starts_with?(object_key, "uploads/tus/")
  end

  defp sibling_variant_key(object_key) do
    dir = Path.dirname(object_key)
    ext = Path.extname(object_key)
    base = Path.basename(object_key, ext)

    if String.ends_with?(base, "_thumb") do
      nil
    else
      join_key(dir, "#{base}_thumb.jpg")
    end
  end

  defp derive_thumb_url(%__MODULE__{file_url: file_url}) do
    if tus_upload?(file_url) do
      file_url
    else
      dir = Path.dirname(file_url)
      ext = Path.extname(file_url)
      base = Path.basename(file_url, ext)

      if String.ends_with?(base, "_thumb") do
        file_url
      else
        "#{dir}/#{base}_thumb.jpg"
      end
    end
  end

  defp extract_object_key(file_url, org_id) do
    cdn = TenantConfig.cdn_url(org_id)

    cond do
      is_binary(cdn) and cdn != "" and
          String.starts_with?(file_url, String.trim_trailing(cdn, "/")) ->
        file_url
        |> String.replace_prefix(String.trim_trailing(cdn, "/"), "")
        |> String.trim_leading("/")

      true ->
        strip_bucket_from_url(file_url, org_id)
    end
  end

  defp strip_bucket_from_url(file_url, org_id) do
    bucket = TenantConfig.bucket(org_id)
    bucket_prefix = "#{bucket}/"

    case URI.parse(file_url) do
      %URI{host: host, path: path} when is_binary(path) ->
        raw_path = String.trim_leading(path, "/")
        virtual_hosted? = is_binary(host) and String.starts_with?(host, "#{bucket}.")

        if not virtual_hosted? and String.starts_with?(raw_path, bucket_prefix) do
          String.replace_prefix(raw_path, bucket_prefix, "")
        else
          raw_path
        end

      _ ->
        String.trim_leading(file_url, "/")
    end
  end

  defp join_key(".", filename), do: filename
  defp join_key(dir, filename), do: "#{dir}/#{filename}"
end
