defmodule AshPhoenixStarter.Uploads.TenantConfig do
  @moduledoc """
  Resolves per-organization ExAws and storage settings from ConCache/Manager.
  Shared between Waffle definitions and Tus chunked uploads.
  """

  alias AshPhoenixStarter.Settings.Manager

  def provider(nil), do: "local"

  def provider(organization_id) do
    (Manager.get_tenant(organization_id, :storage_provider) || "local")
    |> String.downcase()
  end

  def bucket(nil), do: System.get_env("DEFAULT_BUCKET") || "app-uploads"

  def bucket(organization_id) do
    Manager.get_tenant(organization_id, :storage_bucket) ||
      System.get_env("DEFAULT_BUCKET") ||
      "app-uploads"
  end

  def cdn_url(nil), do: nil

  def cdn_url(organization_id) do
    Manager.get_tenant(organization_id, :storage_cdn_url)
  end

  def virtual_host?(nil), do: false

  def virtual_host?(organization_id) do
    case Manager.get_tenant(organization_id, :storage_virtual_host) do
      val when is_boolean(val) -> val
      "true" -> true
      "false" -> false
      _ -> provider(organization_id) == "r2"
    end
  end

  def ex_aws_config(organization_id) do
    provider = provider(organization_id)

    access_key =
      get_tenant_setting(organization_id, :storage_access_key) ||
        System.get_env("STORAGE_ACCESS_KEY")

    secret_key =
      get_tenant_setting(organization_id, :storage_secret_key) ||
        System.get_env("STORAGE_SECRET_KEY")

    host =
      case provider do
        "r2" ->
          get_tenant_setting(organization_id, :storage_host) || System.get_env("R2_HOST")

        "minio" ->
          get_tenant_setting(organization_id, :storage_host) || "localhost:9000"

        _ ->
          get_tenant_setting(organization_id, :storage_host) || "://digitaloceanspaces.com"
      end

    scheme =
      if provider == "minio" and not String.starts_with?(host || "", "https"),
        do: "http://",
        else: "https://"

    [
      access_key_id: access_key,
      secret_access_key: secret_key,
      region: region_for_provider(provider),
      s3: [
        scheme: scheme,
        host: host,
        port: if(scheme == "http://", do: 9000, else: 443),
        virtual_host: virtual_host?(organization_id)
      ]
    ]
  end

  def public_url(organization_id, object_key) do
    clean_key = String.trim_leading(object_key, "/")

    case cdn_url(organization_id) do
      cdn when is_binary(cdn) and cdn != "" ->
        "#{String.trim_trailing(cdn, "/")}/#{clean_key}"

      _ ->
        build_provider_url(organization_id, clean_key)
    end
  end

  defp build_provider_url(organization_id, clean_key) do
    case provider(organization_id) do
      p when p in ["spaces", "s3", "r2", "minio"] ->
        aws_cfg = ex_aws_config(organization_id)
        s3_cfg = Keyword.get(aws_cfg, :s3, [])
        scheme = Keyword.get(s3_cfg, :scheme, "https://")
        host = Keyword.get(s3_cfg, :host, "amazonaws.com")
        bucket = bucket(organization_id)

        if virtual_host?(organization_id) do
          "#{scheme}#{bucket}.#{host}/#{clean_key}"
        else
          "#{scheme}#{host}/#{bucket}/#{clean_key}"
        end

      _ ->
        "/#{clean_key}"
    end
  end

  defp get_tenant_setting(nil, _key), do: nil
  defp get_tenant_setting(organization_id, key), do: Manager.get_tenant(organization_id, key)

  defp region_for_provider("r2"), do: "auto"
  defp region_for_provider("s3"), do: System.get_env("AWS_REGION") || "us-east-1"
  defp region_for_provider(_), do: "us-east-1"
end
