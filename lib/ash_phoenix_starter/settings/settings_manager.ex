defmodule AshPhoenixStarter.Settings.Manager do
  @moduledoc """
  A centralized, cache-backed settings management module built on top of Ash Framework
  and ConCache.

  `Manager` allows you to store, retrieve, and dynamically update configuration
  values of various data types (strings, integers, booleans, floats, and atoms) backed by a
  PostgreSQL database while leveraging an in-memory cache for ultra-fast, zero-database-hit reads
  during application runtime (e.g., inside Phoenix LiveViews).

  ## Features
  * **Dynamic Type Coercion:** Automatically casts database string representations into native Elixir
    types (`integer`, `boolean`, `float`, `atom`, or `string`) based on stored type metadata.
  * **In-Memory Caching:** Uses `ConCache` to prevent repetitive database queries on hot paths.
  * **Cache Invalidation:** Automatically updates or evicts cache entries when a setting is modified.

  ## Usage Examples

  ### 1. Retrieving a Setting
  Fetch a setting by its key. Returns the correctly casted Elixir value, or `nil` if the key
  does not exist:

      # Returns an atom (e.g., :cdn or :local)
      image_mode = AshPhoenixStarter.Settings.Manager.get(:image_mode)

      # Returns an integer limit
      max_size = AshPhoenixStarter.Settings.Manager.get("max_upload_size")

  ### 2. Storing or Updating a Setting
  Persist a new configuration value or update an existing one. The module automatically
  infers the data type if not provided explicitly, persists it via Ash, and updates the in-memory cache:

      # Automatically inferred as an atom
      AshPhoenixStarter.Settings.Manager.put(:image_mode, :cdn)

      # Automatically inferred as an integer
      AshPhoenixStarter.Settings.Manager.put("max_upload_size", 10_485_760)

      # Explicitly setting a boolean flag
      AshPhoenixStarter.Settings.Manager.put("maintenance_mode", true, "boolean")

  ## Architecture & Supervision
  Ensure `ConCache` is started in your application's supervision tree before calling
  `Settings.Manager`:

      children = [
        AshPhoenixStarter.Repo,
        {ConCache, [name: :app_settings_cache, ttl_check_interval: :timer.seconds(60)]},
        AshPhoenixStarterWeb.Endpoint
      ]
  """

  alias AshPhoenixStarter.Settings.Configuration

  @cache_name :app_settings_cache
  @tenant_cache_name :tenant_settings_cache

  def get(key) do
    key_str = to_string(key)

    ConCache.get_or_store(@cache_name, key_str, fn ->
      case Ash.get(Configuration, [key: key_str], not_found_error?: false) do
        nil -> {:error, :not_found}
        config -> {:ok, cast_value(config.value, config.type)}
      end
    end)
    |> case do
      {:ok, val} -> val
      {:error, _} -> nil
    end
  end

  def put(key, value, type \\ nil) do
    key_str = to_string(key)
    inferred_type = type || infer_type(value)
    string_value = serialize_value(value, inferred_type)

    attrs = %{key: key_str, value: string_value, type: inferred_type}

    result =
      case Ash.get(Configuration, [key: key_str], not_found_error?: false) do
        nil ->
          Configuration
          |> Ash.Changeset.for_create(:create, attrs)
          |> Ash.create()

        existing ->
          existing
          |> Ash.Changeset.for_update(:update, attrs)
          |> Ash.update()
      end

    case result do
      {:ok, config} ->
        parsed_val = cast_value(config.value, config.type)
        ConCache.put(@cache_name, key_str, {:ok, parsed_val})
        {:ok, parsed_val}

      error ->
        error
    end
  end

  def get_tenant(id, key) do
    key_str = to_string(id) <> ":" <> to_string(key)

    ConCache.get_or_store(@tenant_cache_name, key_str, fn ->
      case Ash.get(TenantConfiguration, [key: key], not_found_error?: false) do
        nil -> {:error, :not_found}
        config -> {:ok, cast_value(config.value, config.type)}
      end
    end)
    |> case do
      {:ok, val} -> val
      {:error, _} -> nil
    end
  end

  def put_tenant(id, key, value, type \\ nil) do
    key_str = to_string(id) <> ":" <> to_string(key)
    inferred_type = type || infer_type(value)
    string_value = serialize_value(value, inferred_type)

    attrs = %{key: to_string(key), value: string_value, type: inferred_type}

    result =
      case Ash.get(TenantConfiguration, [key: to_string(key)], not_found_error?: false) do
        nil ->
          TenantConfiguration
          |> Ash.Changeset.for_create(:create, attrs)
          |> Ash.create()

        existing ->
          existing
          |> Ash.Changeset.for_update(:update, attrs)
          |> Ash.update()
      end

    case result do
      {:ok, config} ->
        parsed_val = cast_value(config.value, config.type)
        ConCache.put(@tenant_cache_name, key_str, {:ok, parsed_val})
        {:ok, parsed_val}

      error ->
        error
    end
  end

  defp cast_value(val, "integer"), do: String.to_integer(val)
  defp cast_value(val, "float"), do: String.to_float(val)
  defp cast_value("true", "boolean"), do: true
  defp cast_value("false", "boolean"), do: false
  defp cast_value(val, "atom"), do: String.to_existing_atom(val)
  defp cast_value(val, _string), do: val

  defp serialize_value(val, "atom"), do: to_string(val)
  defp serialize_value(val, _), do: to_string(val)

  defp infer_type(val) when is_integer(val), do: "integer"
  defp infer_type(val) when is_float(val), do: "float"
  defp infer_type(val) when is_boolean(val), do: "boolean"
  defp infer_type(val) when is_atom(val), do: "atom"
  defp infer_type(_), do: "string"
end
