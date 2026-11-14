defmodule AshPhoenixStarter.Uploads.TenantConfig do
  @moduledoc """
  Resolves per-organization storage settings and `ExAws` configuration from
  `AshPhoenixStarter.Settings.Manager` with fallback to environment variables.

  Shared across `ImageUploader`, `StorageDispatcher`, `FileAsset`, and `Tussle`
  chunked uploads.

  ## Supported Storage Providers

  * `"local"` — Local filesystem under `priv/static/uploads` (default when unconfigured)
  * `"s3"` — Amazon S3
  * `"r2"` — Cloudflare R2 (automatically defaults `region` to `"auto"` and `virtual_host` to `true`)
  * `"spaces"` — DigitalOcean Spaces
  * `"minio"` — Self-hosted MinIO (defaults to `http://` on port `9000` when no scheme is provided)

  ## Tenant Setting Keys

  Reads the following keys via `Manager.get_tenant(organization_id, key)`:

  * `:storage_provider` — `"local"`, `"s3"`, `"r2"`, `"spaces"`, or `"minio"`
  * `:storage_bucket` — Target bucket name (falls back to `DEFAULT_BUCKET` env var)
  * `:storage_host` — Endpoint hostname (e.g., `"://digitaloceanspaces.com"` or `"localhost:9000"`)
  * `:storage_access_key` — S3 access key ID (falls back to `STORAGE_ACCESS_KEY` env var)
  * `:storage_secret_key` — S3 secret access key (falls back to `STORAGE_SECRET_KEY` env var)
  * `:storage_cdn_url` — Optional custom public CDN base URL (e.g., `"https://example.com"`)
  * `:storage_virtual_host` — Boolean overriding virtual-hosted vs. path-style S3 URLs

  ## Examples

      # Inspect ExAws keyword configuration for an organization
      TenantConfig.ex_aws_config(org_id)
      # => [
      #      access_key_id: "...",
      #      secret_access_key: "...",
      #      region: "auto",
      #      s3: [scheme: "https://", host: "://cloudflarestorage.com", port: 443, virtual_host: true]
      #    ]

      # Resolve the public URL for an uploaded object key
      TenantConfig.public_url(org_id, "uploads/organizations/123/general/logo.png")
      # => "https://example.com/uploads/organizations/123/general/logo.png"
  """

  alias AshPhoenixStarter.Settings.Manager

  @s3_providers ~w(spaces s3 r2 minio)

  @doc """
  Returns `true` if the organization is configured to use an S3-compatible provider
  (`"s3"`, `"r2"`, `"spaces"`, or `"minio"`).
  """
  @spec s3_provider?(String.t() | nil) :: boolean()
  def s3_provider?(organization_id) do
    provider(organization_id) in @s3_providers
  end

  @doc """
  Returns the normalized lowercase storage provider string for `organization_id`.
  Defaults to `"local"` when `organization_id` is `nil` or unconfigured.
  """
  @spec provider(String.t() | nil) :: String.t()
  def provider(nil), do: "local"

  def provider(organization_id) do
    (Manager.get_tenant(organization_id, :storage_provider) || "local")
    |> String.downcase()
  end

  @doc """
  Returns the configured bucket name for `organization_id`, falling back to
  `DEFAULT_BUCKET` or `"app-uploads"`.
  """
  @spec bucket(String.t() | nil) :: String.t()
  def bucket(nil), do: System.get_env("DEFAULT_BUCKET") || "app-uploads"

  def bucket(organization_id) do
    get_tenant_setting(organization_id, :storage_bucket) ||
      System.get_env("DEFAULT_BUCKET") ||
      "app-uploads"
  end

  @doc """
  Returns the custom public CDN URL configured for `organization_id`, or `nil`.
  """
  @spec cdn_url(String.t() | nil) :: String.t() | nil
  def cdn_url(nil), do: nil

  def cdn_url(organization_id) do
    get_tenant_setting(organization_id, :storage_cdn_url)
  end

  @doc """
  Returns whether virtual-hosted-style URLs (`https://bucket.host`) should be used
  instead of path-style URLs (`https://host/bucket/key`). Defaults to `true` for `"r2"`.
  """
  @spec virtual_host?(String.t() | nil) :: boolean()
  def virtual_host?(nil), do: false

  def virtual_host?(organization_id) do
    case Manager.get_tenant(organization_id, :storage_virtual_host) do
      val when is_boolean(val) -> val
      "true" -> true
      "false" -> false
      _ -> provider(organization_id) == "r2"
    end
  end

  @doc """
  Builds a complete `ExAws` configuration keyword list for `organization_id`,
  ready to pass to `ExAws.request(op, config)`.
  """
  @spec ex_aws_config(String.t() | nil) :: keyword()
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
          get_tenant_setting(organization_id, :storage_host) || "://digitaloceanspaces.com"

        _ ->
          get_tenant_setting(organization_id, :storage_host) || "://amazonaws.com"
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

  @doc """
  Resolves the publicly accessible URL for `object_key` under `organization_id`.

  Prefers `:storage_cdn_url` if configured; otherwise constructs either a virtual-hosted
  S3 URL, path-style S3 URL, or relative local path (`/uploads/...`).
  """
  @spec public_url(String.t() | nil, String.t()) :: String.t()
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
      host = Keyword.get(s3_cfg, :host, "://amazonaws.com")
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
