defmodule AshPhoenixStarter.Settings.Manager do
  @moduledoc """
  A centralized, cache-backed settings management module built on top of Ash Framework
  and Nebulex.

  `Manager` stores, retrieves, and dynamically updates configuration values
  (strings, maps, lists, integers, booleans, floats, and atoms) in PostgreSQL
  while caching reads in `AppSettings` and `TenantSettings` ETS caches.
  """

  alias AshPhoenixStarter.Cache.{AppSettings, TenantSettings}
  alias AshPhoenixStarter.Settings
  alias AshPhoenixStarter.Settings.Organization
  alias AshPhoenixStarter.Settings.Payment.Gateway.Setting, as: Gateway

  # ============================================================================
  # GLOBAL SETTINGS
  # ============================================================================

  @doc """
  Fetches a global setting by `key`, reading from `AppSettings` cache first
  and falling back to PostgreSQL on cache miss.
  """
  @spec get(atom() | String.t()) :: term()
  def get(key) do
    key_str = to_string(key)

    fetch_cached(AppSettings, key_str, AppSettings.default_ttl(), fn ->
      case Ash.get(Settings, [key: key_str], not_found_error?: false) do
        {:ok, %Settings{} = config} -> {:ok, cast_value(config.value, config.type)}
        _ -> :miss
      end
    end)
  end

  @doc """
  Creates or updates a global setting in PostgreSQL and updates `AppSettings` cache.
  """
  @spec put(atom() | String.t(), term(), atom() | String.t() | nil) ::
          {:ok, term()} | {:error, term()}
  def put(key, value, type \\ nil) do
    key_str = to_string(key)
    inferred_type = normalize_type(type || infer_type(value))
    attrs = %{key: key_str, value: serialize_value(value), type: inferred_type}

    with {:ok, config} <- upsert_global(key_str, attrs) do
      parsed_val = cast_value(config.value, config.type)
      AppSettings.put(key_str, parsed_val, ttl: AppSettings.default_ttl())
      {:ok, parsed_val}
    end
  end

  # ============================================================================
  # TENANT SETTINGS
  # ============================================================================

  @doc """
  Fetches a tenant-scoped setting by organization `id` and `key`.
  """
  @spec get_tenant(String.t(), atom() | String.t()) :: term()
  def get_tenant(id, key) do
    key_str = to_string(key)
    cache_key = "#{id}:#{key_str}"

    fetch_cached(TenantSettings, cache_key, TenantSettings.default_ttl(), fn ->
      case Ash.get(Organization, [key: key_str], tenant: id, not_found_error?: false) do
        {:ok, %Organization{} = config} -> {:ok, cast_value(config.value, config.type)}
        _ -> :miss
      end
    end)
  end

  @doc """
  Fetches a tenant-scoped payment gateway configuration record.
  """
  @spec get_tenant(String.t(), atom() | String.t(), :gateway) :: term()
  def get_tenant(id, gateway_type, :gateway) do
    cache_key = "#{id}:gateway:#{gateway_type}"

    fetch_cached(TenantSettings, cache_key, TenantSettings.default_ttl(), fn ->
      case Ash.get(Gateway, [gateway_type: gateway_type], tenant: id, not_found_error?: false) do
        {:ok, %Gateway{} = config} -> {:ok, config}
        _ -> :miss
      end
    end)
  end

  @doc """
  Creates or updates a tenant-scoped setting in PostgreSQL and updates `TenantSettings` cache.
  """
  @spec put_tenant(String.t(), atom() | String.t(), term(), atom() | String.t() | nil) ::
          {:ok, term()} | {:error, term()}
  def put_tenant(id, key, value, type \\ nil) do
    key_str = to_string(key)
    cache_key = "#{id}:#{key_str}"
    inferred_type = normalize_type(type || infer_type(value))
    attrs = %{key: key_str, value: serialize_value(value), type: inferred_type}

    with {:ok, config} <- upsert_tenant(id, key_str, attrs) do
      parsed_val = cast_value(config.value, config.type)
      TenantSettings.put(cache_key, parsed_val, ttl: TenantSettings.default_ttl())
      {:ok, parsed_val}
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp fetch_cached(cache_mod, cache_key, ttl, loader_fun) do
    case cache_mod.get(cache_key) do
      nil ->
        case loader_fun.() do
          {:ok, val} ->
            cache_mod.put(cache_key, val, ttl: ttl)
            val

          :miss ->
            nil
        end

      cached_val ->
        cached_val
    end
  end

  defp upsert_global(key_str, attrs) do
    case Ash.get(Settings, [key: key_str], not_found_error?: false) do
      {:ok, %Settings{} = existing} ->
        existing
        |> Ash.Changeset.for_update(:update, attrs)
        |> Ash.update()

      _ ->
        Settings
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.create()
    end
  end

  defp upsert_tenant(id, key_str, attrs) do
    case Ash.get(Organization, [key: key_str], tenant: id, not_found_error?: false) do
      {:ok, %Organization{} = existing} ->
        existing
        |> Ash.Changeset.for_update(:update, attrs)
        |> Ash.update()

      _ ->
        Organization
        |> Ash.Changeset.for_create(:create, attrs, tenant: id)
        |> Ash.create()
    end
  end

  defp cast_value(nil, _type), do: nil
  defp cast_value(val, "integer"), do: String.to_integer(val)
  defp cast_value(val, "float"), do: String.to_float(val)
  defp cast_value(val, "map"), do: Jason.decode!(val)
  defp cast_value(val, "list"), do: Jason.decode!(val)
  defp cast_value("true", "boolean"), do: true
  defp cast_value("false", "boolean"), do: false
  defp cast_value(val, "atom"), do: String.to_existing_atom(val)
  defp cast_value(val, _string), do: val

  defp serialize_value(val) when is_map(val) or is_list(val), do: Jason.encode!(val)
  defp serialize_value(val), do: to_string(val)

  defp normalize_type(type) when is_atom(type), do: Atom.to_string(type)
  defp normalize_type(type) when is_binary(type), do: type

  defp infer_type(val) when is_integer(val), do: "integer"
  defp infer_type(val) when is_float(val), do: "float"
  defp infer_type(val) when is_boolean(val), do: "boolean"
  defp infer_type(val) when is_atom(val), do: "atom"
  defp infer_type(val) when is_map(val), do: "map"
  defp infer_type(val) when is_list(val), do: "list"
  defp infer_type(_), do: "string"

    # ============================================================================
  # DELETE & CACHE EVICTION
  # ============================================================================

  @doc """
  Deletes a global setting from PostgreSQL and evicts it from `AppSettings` cache.
  Returns `:ok` whether the setting existed in the database or not.
  """
  @spec delete(atom() | String.t()) :: :ok | {:error, term()}
  def delete(key) do
    key_str = to_string(key)

    result =
      case Ash.get(Settings, [key: key_str], not_found_error?: false) do
        {:ok, %Settings{} = existing} -> Ash.destroy(existing)
        _ -> :ok
      end

    with :ok <- normalize_destroy_result(result) do
      AppSettings.delete(key_str)
      :ok
    end
  end

  @doc """
  Deletes a tenant-scoped setting from PostgreSQL and evicts it from `TenantSettings` cache.
  Returns `:ok` whether the setting existed in the database or not.
  """
  @spec delete_tenant(String.t(), atom() | String.t()) :: :ok | {:error, term()}
  def delete_tenant(id, key) do
    key_str = to_string(key)
    cache_key = "#{id}:#{key_str}"

    result =
      case Ash.get(Organization, [key: key_str], tenant: id, not_found_error?: false) do
        {:ok, %Organization{} = existing} -> Ash.destroy(existing)
        _ -> :ok
      end

    with :ok <- normalize_destroy_result(result) do
      TenantSettings.delete(cache_key)
      :ok
    end
  end

  @doc """
  Evicts a cached tenant payment gateway configuration from `TenantSettings`.
  Call this from an Ash `after_action` hook whenever a `Gateway` record is updated or destroyed.
  """
  @spec evict_gateway(String.t(), atom() | String.t()) :: :ok
  def evict_gateway(id, gateway_type) do
    TenantSettings.delete("#{id}:gateway:#{gateway_type}")
    :ok
  end

  defp normalize_destroy_result(:ok), do: :ok
  defp normalize_destroy_result({:ok, _}), do: :ok
  defp normalize_destroy_result(error), do: error

end
