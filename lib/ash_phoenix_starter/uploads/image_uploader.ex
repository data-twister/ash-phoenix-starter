defmodule AshPhoenixStarter.Uploads.ImageUploader do
  use Waffle.Definition
  use Waffle.Ecto.Definition

  alias AshPhoenixStarter.Settings.Manager

  @versions [:original, :thumb]
  @extensions ~w(jpg jpeg png webp)

  # Point Waffle to our multi-backend dispatcher
  def storage do
    AshPhoenixStarter.Uploads.StorageDispatcher
  end

  # Dynamically pull the correct bucket name from ConCache
  def bucket(_version, {_, scope}) do
    Manager.get_tenant(scope.organization_id, :storage_bucket) ||
      System.get_env("DEFAULT_BUCKET") ||
      "app-uploads"
  end

  # Dynamically configure ExAws credentials & custom endpoints (vital for Cloudflare R2 or MinIO)
  def ex_aws_config({_, scope}) do
    organization_id = scope.organization_id
    provider = Manager.get_tenant(organization_id, :storage_provider) || "spaces"

    access_key =
      Manager.get_tenant(organization_id, :storage_access_key) ||
        System.get_env("STORAGE_ACCESS_KEY")

    secret_key =
      Manager.get_tenant(organization_id, :storage_secret_key) ||
        System.get_env("STORAGE_SECRET_KEY")

    # Custom host/endpoint mapping for different S3-compatible providers
    host =
      case provider do
        "r2" ->
          # Cloudflare R2 requires a custom account endpoint URL
          Manager.get_tenant(organization_id, :storage_host) || System.get_env("R2_HOST")

        "minio" ->
          Manager.get_tenant(organization_id, :storage_host) || "localhost:9000"

        _ ->
          # Default to DigitalOcean Spaces region endpoint
          Manager.get_tenant(organization_id, :storage_host) || "nyc3.digitaloceanspaces.com"
      end

    scheme =
      if provider == "minio" and not String.starts_with?(host, "https"),
        do: "http://",
        else: "https://"

    [
      access_key_id: access_key,
      secret_access_key: secret_key,
      region: get_region_for_provider(provider),
      s3: [
        scheme: scheme,
        host: host,
        port: if(scheme == "http://", do: 9000, else: 443),
        # Cloudflare R2 often requires virtual-hosted style requests
        virtual_host: provider == "r2"
      ]
    ]
  end

  defp get_region_for_provider("r2"), do: "auto"
  defp get_region_for_provider("s3"), do: System.get_env("AWS_REGION") || "us-east-1"
  defp get_region_for_provider(_), do: "us-east-1"

  # Custom CDN URL mapping from ConCache
  def url(version, {_file, scope} = file_scope, options) do
    cdn_url = Manager.get_tenant(scope.organization_id, :storage_cdn_url)

    if cdn_url do
      "#{String.trim_trailing(cdn_url, "/")}/#{storage_dir(version, file_scope)}/#{filename(version, file_scope)}"
    else
      super(version, file_scope, options)
    end
  end

  def validate({file, _spec}) do
    file.file_name
    |> Path.extname()
    |> String.downcase()
    |> String.trim_leading(".")
    |> then(&Enum.member?(@extensions, &1))
  end

  def transform(:thumb, _) do
    {:convert, "-thumbnail 300x300^ -gravity center -extent 300x300", :jpg}
  end

  def filename(:original, {file, _}) do
    Path.basename(file.file_name, Path.extname(file.file_name))
  end

  def filename(:thumb, {file, _}) do
    "#{Path.basename(file.file_name, Path.extname(file.file_name))}_thumb"
  end

  def storage_dir_version_prefix?, do: true

  # `scope.type` is :service, :feature, etc. (see AshPhoenixStarter.Core.FileAsset's
  # `:type` attribute) -- this is what actually produces
  # "uploads/service/<name>.ext" / "uploads/feature/<name>.ext". Tenant
  # isolation still happens one layer up, via `bucket/2` selecting a
  # per-organization bucket, so this doesn't need a organizations/<organization_id> segment too.
  def storage_dir(_, {_, scope}) do
    case scope.type do
      :service -> "uploads/service/"
      :feature -> "uploads/feature/"
      _ -> "uploads/organizations/#{scope.organization_id}/#{scope.type}"
    end
  end
end
