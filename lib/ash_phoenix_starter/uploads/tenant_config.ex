defmodule AshPhoenixStarter.Uploads.TenantConfig do
  @moduledoc """
  Resolves per-organization ExAws and storage settings from Cachex/Manager.
  Shared between image uploads and Tus chunked uploads.
  """

  alias AshPhoenixStarter.Settings.Manager

  @s3_providers ~w(spaces s3 r2 minio)

  def s3_provider?(organization_id) do
    provider(organization_id) in @s3_providers
  end

  def provider(nil), do: "local"

  def provider(organization_id) do
    (Manager.get_tenant(organization_id, :storage_provider) || "local")
    |> String.downcase()
  end

  def bucket(nil), do: System.get_env("DEFAULT_BUCKET") || "app-uploads"

  def bucket(organization_id) do
    get_tenant_setting(organization_id, :storage_bucket) ||
      System.get_env("DEFAULT_BUCKET") ||
      "app-uploads"
  end

  def cdn_url(nil), do: nil

  def cdn_url(organization_id) do
    get_tenant_setting(organization_id, :storage_cdn_url)
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

    raw_host =
      case provider do
        "r2" ->
          get_tenant_setting(organization_id, :storage_host) || System.get_env("R2_HOST")

        "minio" ->
          get_tenant_setting(organization_id, :storage_host) || "localhost:9000"

        "spaces" ->
          get_tenant_setting(organization_id, :storage_host) || "nyc3.digitaloceanspaces.com"

        _ ->
          get_tenant_setting(organization_id, :storage_host) || "s3.amazonaws.com"
      end

    {scheme, clean_host, port} = parse_endpoint(provider, raw_host)

    [
      access_key_id: access_key,
      secret_access_key: secret_key,
      region: region_for_provider(provider),
      s3: [
        scheme: scheme,
        host: clean_host,
        port: port,
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

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp build_provider_url(organization_id, clean_key) do
    if s3_provider?(organization_id) do
      aws_cfg = ex_aws_config(organization_id)
      s3_cfg = Keyword.get(aws_cfg, :s3, [])
      scheme = Keyword.get(s3_cfg, :scheme, "https://")
      host = Keyword.get(s3_cfg, :host, "s3.amazonaws.com")
      bucket = bucket(organization_id)

      if virtual_host?(organization_id) do
        "#{scheme}#{bucket}.#{host}/#{clean_key}"
      else
        "#{scheme}#{host}/#{bucket}/#{clean_key}"
      end
    else
      "/#{clean_key}"
    end
  end

  defp parse_endpoint(provider, raw_host) do
    host_str = raw_host || ""

    cond do
      String.starts_with?(host_str, "http://") ->
        stripped = String.replace_prefix(host_str, "http://", "")
        {"http://", stripped, extract_port(stripped, 80)}

      String.starts_with?(host_str, "https://") ->
        stripped = String.replace_prefix(host_str, "https://", "")
        {"https://", stripped, extract_port(stripped, 443)}

      provider == "minio" ->
        {"http://", host_str, extract_port(host_str, 9000)}

      true ->
        {"https://", host_str, extract_port(host_str, 443)}
    end
  end

  defp extract_port(host, default_port) do
    case String.split(host, ":") do
      [_hostname, port_str] -> String.to_integer(port_str)
      _ -> default_port
    end
  end

  defp get_tenant_setting(nil, _key), do: nil

  defp get_tenant_setting(organization_id, key) do
    case Manager.get_tenant(organization_id, key) do
      val when is_binary(val) ->
        case String.trim(val) do
          "" -> nil
          trimmed -> trimmed
        end

      val ->
        val
    end
  end

  defp region_for_provider("r2"), do: "auto"
  defp region_for_provider("s3"), do: System.get_env("AWS_REGION") || "us-east-1"
  defp region_for_provider(_), do: "us-east-1"
end
