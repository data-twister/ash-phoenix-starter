defmodule AshPhoenixStarter.Core.FileAsset do
  use Ash.Resource,
    domain: AshPhoenixStarter.Core,
    data_layer: AshPostgres.DataLayer

  alias AshPhoenixStarter.Uploads.{StorageDispatcher, TenantConfig}

  postgres do
    table "file_assets"
    repo AshPhoenixStarter.Repo
  end

  code_interface do
    define :read, action: :read
    define :list, action: :read
    define :create, action: :create
    define :destroy, action: :destroy
  end

  actions do
    defaults [:read]

    create :create do
      accept [:filename, :file_url, :file_size, :content_type, :organization_id, :type]
    end

    destroy :destroy do
      primary? true

      change after_transaction(fn _changeset, {:ok, record}, _context ->
               delete_remote_file(record)
               {:ok, record}
             end)

      change after_transaction(fn _changeset, {:error, error}, _context ->
               {:error, error}
             end)
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :filename, :string, allow_nil?: false
    attribute :file_url, :string, allow_nil?: false
    attribute :file_size, :integer
    attribute :content_type, :string
    attribute :organization_id, :uuid, allow_nil?: true

    attribute :type, :atom do
      constraints one_of: [:general]
      default :general
      allow_nil? false
    end

    timestamps()
  end

  defp delete_remote_file(%__MODULE__{file_url: file_url, organization_id: org_id}) do
    object_key = extract_object_key(file_url, org_id)

    if tus_upload?(object_key) do
      delete_s3_object(object_key, org_id)
    else
      delete_waffle_variants(object_key, org_id)
    end
  end

  defp tus_upload?(object_key) do
    String.contains?(object_key, "/tus/") or String.starts_with?(object_key, "uploads/tus/")
  end

  defp delete_waffle_variants(object_key, org_id) do
    delete_s3_object(object_key, org_id)

    dir = Path.dirname(object_key)
    ext = Path.extname(object_key)
    base = Path.basename(object_key, ext)

    sibling_key =
      if String.ends_with?(base, "_thumb") do
        nil
      else
        Path.join(dir, "#{base}_thumb.jpg")
      end

    if sibling_key, do: delete_s3_object(sibling_key, org_id)
  end

  defp delete_s3_object(object_key, org_id) do
    uid = Path.basename(object_key)
    prefix = Path.dirname(object_key) |> then(&if &1 == ".", do: "", else: &1)

    StorageDispatcher.delete(
      %{uid: uid, offset: 0, size: 0, path: object_key},
      %{organization_id: org_id, s3_prefix: prefix}
    )
  end

  defp extract_object_key(file_url, org_id) do
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
end
