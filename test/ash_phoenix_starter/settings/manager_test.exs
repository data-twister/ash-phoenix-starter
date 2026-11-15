defmodule AshPhoenixStarter.Settings.ManagerTest do
  use AshPhoenixStarter.DataCase, async: false

  alias AshPhoenixStarter.Cache.{AppSettings, TenantSettings}
  alias AshPhoenixStarter.Settings.Manager

  setup do
    AppSettings.delete_all()
    TenantSettings.delete_all()
    :ok
  end

  describe "global settings (get/1, put/3, delete/1)" do
    test "stores, casts, and retrieves all supported data types" do
      assert {:ok, "hello"} = Manager.put(:site_name, "hello")
      assert Manager.get(:site_name) == "hello"

      assert {:ok, 42} = Manager.put(:max_retries, 42)
      assert Manager.get(:max_retries) === 42

      assert {:ok, 3.14} = Manager.put(:tax_rate, 3.14)
      assert Manager.get(:tax_rate) === 3.14

      assert {:ok, false} = Manager.put(:maintenance_mode, false)
      assert Manager.get(:maintenance_mode) === false

      assert {:ok, :cdn} = Manager.put(:image_mode, :cdn)
      assert Manager.get(:image_mode) === :cdn

      assert {:ok, %{"theme" => "dark"}} = Manager.put(:ui_prefs, %{"theme" => "dark"})
      assert Manager.get(:ui_prefs) == %{"theme" => "dark"}

      assert {:ok, ["a", "b"]} = Manager.put(:allowed_tags, ["a", "b"])
      assert Manager.get(:allowed_tags) == ["a", "b"]
    end

    test "caches values in AppSettings and serves subsequent reads from ETS" do
      assert {:ok, "cached_val"} = Manager.put(:fast_key, "cached_val")
      assert AppSettings.get("fast_key") == "cached_val"

      # Overwrite directly in Nebulex to prove Manager.get/1 reads from cache first
      AppSettings.put("fast_key", "from_ets_memory")
      assert Manager.get(:fast_key) == "from_ets_memory"
    end

    test "updates existing global settings and refreshes cache" do
      assert {:ok, 10} = Manager.put(:batch_size, 10)
      assert {:ok, 25} = Manager.put(:batch_size, 25)

      assert Manager.get(:batch_size) == 25
      assert AppSettings.get("batch_size") == 25
    end

    test "delete/1 removes setting from both database and AppSettings cache" do
      assert {:ok, "temp"} = Manager.put(:ephemeral_key, "temp")
      assert AppSettings.get("ephemeral_key") == "temp"

      assert :ok = Manager.delete(:ephemeral_key)
      assert AppSettings.get("ephemeral_key") == nil
      assert Manager.get(:ephemeral_key) == nil
    end
  end

  describe "tenant settings (get_tenant/2, put_tenant/4, delete_tenant/2)" do
    test "isolates settings per tenant and caches in TenantSettings" do
      org_a = Ash.UUID.generate()
      org_b = Ash.UUID.generate()

      assert {:ok, "s3"} = Manager.put_tenant(org_a, :storage_provider, "s3")
      assert {:ok, "r2"} = Manager.put_tenant(org_b, :storage_provider, "r2")

      assert Manager.get_tenant(org_a, :storage_provider) == "s3"
      assert Manager.get_tenant(org_b, :storage_provider) == "r2"

      assert TenantSettings.get("#{org_a}:storage_provider") == "s3"
      assert TenantSettings.get("#{org_b}:storage_provider") == "r2"
    end

    test "delete_tenant/2 removes setting from both database and TenantSettings cache" do
      org_id = Ash.UUID.generate()

      assert {:ok, "my-bucket"} = Manager.put_tenant(org_id, :storage_bucket, "my-bucket")
      assert TenantSettings.get("#{org_id}:storage_bucket") == "my-bucket"

      assert :ok = Manager.delete_tenant(org_id, :storage_bucket)
      assert TenantSettings.get("#{org_id}:storage_bucket") == nil
      assert Manager.get_tenant(org_id, :storage_bucket) == nil
    end

    test "evict_gateway/2 clears cached gateway key from TenantSettings" do
      org_id = Ash.UUID.generate()
      cache_key = "#{org_id}:gateway:stripe"

      TenantSettings.put(cache_key, %{id: "fake_gateway"})
      assert TenantSettings.get(cache_key) != nil

      assert :ok = Manager.evict_gateway(org_id, :stripe)
      assert TenantSettings.get(cache_key) == nil
    end
  end
end
