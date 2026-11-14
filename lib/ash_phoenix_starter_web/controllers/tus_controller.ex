defmodule AshPhoenixStarterWeb.TusController do
  use AshPhoenixStarterWeb, :controller
  use Tussle.Controller

  alias AshPhoenixStarter.Core.FileAsset
  alias AshPhoenixStarter.Settings.Manager
  alias AshPhoenixStarter.Uploads.{StorageDispatcher, TenantConfig}

  @default_max_size 500 * 1024 * 1024

  # Runs on POST when upload begins; stamps `organization_id` onto `file.metadata`
  # so every chunk (`PATCH`) and `on_complete_upload` knows which tenant owns the file.
  def on_begin_upload(file, conn) do
    max_size = Manager.get(:max_upload_size) || @default_max_size

    if file.size > max_size do
      {:error, :file_too_large}
    else
      org_id = resolve_organization_id(conn)
      updated_meta = Map.put(file.metadata || %{}, "organization_id", org_id)
      {:ok, %{file | metadata: updated_meta}}
    end
  end

  # Triggered when all chunks finish uploading
  def on_complete_upload(file) do
    meta = Map.get(file, :metadata, %{})
    org_id = Map.get(meta, "organization_id")
    object_key = normalize_object_key(file.path)

    asset_params = %{
      organization_id: org_id,
      filename: Map.get(meta, "filename", file.uid),
      file_url: TenantConfig.public_url(org_id, object_key),
      file_size: file.size,
      content_type: Map.get(meta, "filetype", "application/octet-stream"),
      type: :general
    }

    case FileAsset.create(asset_params) do
      {:ok, _asset} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_object_key(path) when is_binary(path) do
    path
    |> String.trim_leading("/")
    |> String.replace_prefix("priv/static/", "")
  end

  defp resolve_organization_id(conn) do
    cond do
      org = Map.get(conn.assigns, :current_organization) ->
        org.id

      user = Map.get(conn.assigns, :current_user) ->
        resolve_user_org_uuid(user)

      true ->
        nil
    end
  end

  defp resolve_user_org_uuid(%{organization: %{id: org_id}}) when is_binary(org_id), do: org_id

  defp resolve_user_org_uuid(%{current_organization: domain} = user) when is_binary(domain) do
    case Ash.load(user, :organization, actor: user) do
      {:ok, %{organization: %{id: org_id}}} -> org_id
      _ -> nil
    end
  end

  defp resolve_user_org_uuid(_user), do: nil
end
