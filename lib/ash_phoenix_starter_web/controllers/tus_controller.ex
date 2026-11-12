defmodule AshPhoenixStarterWeb.TusController do
  use AshPhoenixStarterWeb, :controller
  use Tus.Controller

  alias AshPhoenixStarter.Core.FileAsset
  alias AshPhoenixStarter.Uploads.{StorageDispatcher, TenantConfig}

  @impl Tus.Controller
  def init_config(conn) do
    org_id = resolve_organization_id(conn)

    s3_prefix =
      if org_id do
        "uploads/organizations/#{org_id}/tus"
      else
        "uploads/tus"
      end

    %{
      storage: StorageDispatcher,
      cache: Tus.Cache.Memory,
      organization_id: org_id,
      s3_prefix: s3_prefix,
      max_size: 500 * 1024 * 1024
    }
  end

  @impl Tus.Controller
  def on_complete_upload(file, config) do
    org_id = config.organization_id
    meta = Map.get(file, :metadata, %{})
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
      {:ok, _asset} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Strips "priv/static/" when Tus.Storage.Local writes to disk so public URLs resolve cleanly
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
