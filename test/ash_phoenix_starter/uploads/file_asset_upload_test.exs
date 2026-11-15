defmodule AshPhoenixStarter.Uploads.FileAssetUploadTest do
  use AshPhoenixStarter.DataCase, async: false

  alias AshPhoenixStarter.Core.FileAsset
  alias AshPhoenixStarter.Settings.Manager
  alias AshPhoenixStarter.Uploads.{ImageUploader, TenantConfig}

  # Minimal valid 1x1 transparent PNG binary
  @tiny_png <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1,
              8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 11, 73, 68, 65, 84, 120, 156, 99, 96, 0, 2,
              0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130>>

  setup do
    org_id = Ash.UUID.generate()
    upload_dir = Path.join(["priv/static/uploads/organizations", org_id])

    # Force local mode so tests run offline without touching S3
    previous_mode = Manager.get(:image_mode)
    Manager.put(:image_mode, :local)

    on_exit(fn ->
      File.rm_rf!(upload_dir)
      Manager.put(:image_mode, previous_mode)
    end)

    {:ok, org_id: org_id, upload_dir: upload_dir}
  end

  describe "ImageUploader" do
    test "validates allowed extensions and rejects disallowed extensions" do
      assert :ok = ImageUploader.validate(%{file_name: "photo.PNG", binary: @tiny_png})
      assert :ok = ImageUploader.validate(%{file_name: "banner.webp", binary: @tiny_png})

      assert {:error, :invalid_extension} =
               ImageUploader.validate(%{file_name: "payload.exe", binary: "MZ"})

      assert {:error, :invalid_extension} =
               ImageUploader.validate(%{file_name: "document.pdf", binary: "%PDF"})
    end

    test "rejects files exceeding max_upload_size" do
      previous_max = Manager.get(:max_upload_size)
      Manager.put(:max_upload_size, 10)

      on_exit(fn -> Manager.put(:max_upload_size, previous_max) end)

      assert {:error, :file_too_large} =
               ImageUploader.validate(%{file_name: "large.png", binary: @tiny_png})
    end

    test "stores both :original and :thumb versions locally and deletes both", %{org_id: org_id} do
      scope = %{organization_id: org_id, type: :general}
      file = %{file_name: "avatar.png", binary: @tiny_png}

      assert {:ok, "avatar.png"} = ImageUploader.store(file, scope)

      original_path = "priv/static/uploads/organizations/#{org_id}/general/avatar.png"
      thumb_path = "priv/static/uploads/organizations/#{org_id}/general/avatar_thumb.jpg"

      assert File.exists?(original_path)
      assert File.exists?(thumb_path)

      assert ImageUploader.url("avatar.png", scope, :original) ==
               "/uploads/organizations/#{org_id}/general/avatar.png"

      assert ImageUploader.url("avatar.png", scope, :thumb) ==
               "/uploads/organizations/#{org_id}/general/avatar_thumb.jpg"

      # Cleanup via ImageUploader.delete/2
      assert :ok = ImageUploader.delete("avatar.png", scope)
      refute File.exists?(original_path)
      refute File.exists?(thumb_path)
    end
  end

  describe "FileAsset.upload/2 and destroy/1" do
    test "uploads file, creates database record, and calculates thumb_url", %{org_id: org_id} do
      file = %{
        file_name: "logo.png",
        binary: @tiny_png,
        content_type: "image/png"
      }

      assert {:ok, asset} = FileAsset.upload(file, %{organization_id: org_id, type: :general})

      assert asset.filename == "logo.png"
      assert asset.file_url == "/uploads/organizations/#{org_id}/general/logo.png"
      assert asset.file_size == byte_size(@tiny_png)
      assert asset.content_type == "image/png"
      assert asset.organization_id == org_id

      # Verify Ash calculation resolves thumb_url
      loaded_asset = Ash.load!(asset, :thumb_url)
      assert loaded_asset.thumb_url == "/uploads/organizations/#{org_id}/general/logo_thumb.jpg"

      # Verify files exist on disk
      assert File.exists?("priv/static#{asset.file_url}")
      assert File.exists?("priv/static#{loaded_asset.thumb_url}")
    end

    test "returns validation error and writes no files when extension is invalid", %{org_id: org_id} do
      bad_file = %{file_name: "script.sh", binary: "#!/bin/sh\necho hi"}

      assert {:error, %Ash.Error.Invalid{}} =
               FileAsset.upload(bad_file, %{organization_id: org_id})

      refute File.exists?("priv/static/uploads/organizations/#{org_id}/general/script.sh")
    end

    test "destroying FileAsset deletes both original and thumbnail files", %{org_id: org_id} do
      file = %{file_name: "cover.png", binary: @tiny_png}
      {:ok, asset} = FileAsset.upload(file, %{organization_id: org_id})

      original_disk_path = "priv/static/uploads/organizations/#{org_id}/general/cover.png"
      thumb_disk_path = "priv/static/uploads/organizations/#{org_id}/general/cover_thumb.jpg"

      assert File.exists?(original_disk_path)
      assert File.exists?(thumb_disk_path)

      assert :ok = FileAsset.destroy(asset)

      refute File.exists?(original_disk_path)
      refute File.exists?(thumb_disk_path)
    end
  end

  describe "TenantConfig URL & endpoint resolution" do
    test "builds virtual-hosted URLs for Cloudflare R2", %{org_id: org_id} do
      Manager.put_tenant(org_id, :storage_provider, "r2")
      Manager.put_tenant(org_id, :storage_bucket, "tenant-media")
      Manager.put_tenant(org_id, :storage_host, "://cloudflarestorage.com")

      url = TenantConfig.public_url(org_id, "uploads/organizations/#{org_id}/general/pic.png")

      assert url ==
               "https://tenant-media.://cloudflarestorage.com/uploads/organizations/#{org_id}/general/pic.png"
    end

    test "prefers custom CDN URL when configured", %{org_id: org_id} do
      Manager.put_tenant(org_id, :storage_provider, "s3")
      Manager.put_tenant(org_id, :storage_cdn_url, "https://example.com")

      url = TenantConfig.public_url(org_id, "/uploads/general/pic.png")
      assert url == "https://example.comuploads/general/pic.png"
    end

    test "parses MinIO http scheme and port cleanly", %{org_id: org_id} do
      Manager.put_tenant(org_id, :storage_provider, "minio")
      Manager.put_tenant(org_id, :storage_host, "http://localhost:9000")

      cfg = TenantConfig.ex_aws_config(org_id)
      s3_cfg = Keyword.fetch!(cfg, :s3)

      assert s3_cfg[:scheme] == "http://"
      assert s3_cfg[:host] == "localhost:9000"
      assert s3_cfg[:port] == 9000
      assert s3_cfg[:virtual_host] == false
    end
  end
end
