defmodule AshPhoenixStarter.Settings.Manager do
  @moduledoc """
  A centralized, cache-backed settings management module built on top of Ash Framework
  and Cachex.

  `Manager` allows you to store, retrieve, and dynamically update configuration
  values of various data types (strings, maps, integers, booleans, floats, and atoms) backed by a
  PostgreSQL database while leveraging an in-memory cache for ultra-fast, zero-database-hit reads
  during application runtime (e.g., inside Phoenix LiveViews).
  """

  alias AshPhoenixStarter.Settings
  alias AshPhoenixStarter.Settings.Organization
  alias AshPhoenixStarter.Settings.Payment.Gateway.Setting, as: Gateway

  @cache_name :app_settings_cache
  @tenant_cache_name :tenant_settings_cache

  def get(key) do
    key_str = to_string(key)

    result =
      Cachex.fetch(@cache_name, key_str, fn _key ->
        case Ash.get(Settings, [key: key_str], not_found_error?: false) do
          {:ok, nil} ->
            {:ignore, nil}

          nil ->
            {:ignore, nil}

          {:ok, config} ->
            {:commit, cast_value(config.value, config.type)}

          {:error, _} ->
            {:ignore, nil}
        end
      end)

    case result do
      {:ok, val} -> val
      {:commit, val} -> val
      {:ignore, _} -> nil
      _ -> nil
    end
  end

  def put(key, value, type \\ nil) do
    key_str = to_string(key)
    inferred_type = type || infer_type(value)
    string_value = serialize_value(value, inferred_type)

    attrs = %{key: key_str, value: string_value, type: inferred_type}

    result =
      case Ash.get(Settings, [key: key_str], not_found_error?: false) do
        nil ->
          Settings
          |> Ash.Changeset.for_create(:create, attrs)
          |> Ash.create()

        {:ok, nil} ->
          Settings
          |> Ash.Changeset.for_create(:create, attrs)
          |> Ash.create()

        {:ok, existing} ->
          existing
          |> Ash.Changeset.for_update(:update, attrs)
          |> Ash.update()

        existing ->
          existing
          |> Ash.Changeset.for_update(:update, attrs)
          |> Ash.update()
      end

    case result do
      {:ok, config} ->
        parsed_val = cast_value(config.value, config.type)
        Cachex.put(@cache_name, key_str, parsed_val)
        {:ok, parsed_val}

      error ->
        error
    end
  end

  def get_tenant(id, key) do
    key_str = to_string(id) <> ":" <> to_string(key)

    result =
      Cachex.fetch(@tenant_cache_name, key_str, fn _key ->
        case Ash.get(Organization, [key: to_string(key)], tenant: id, not_found_error?: false) do
          {:ok, nil} ->
            {:ignore, nil}

          nil ->
            {:ignore, nil}

          {:ok, config} ->
            {:commit, cast_value(config.value, config.type)}

          {:error, _} ->
            {:ignore, nil}
        end
      end)

    case result do
      {:ok, val} -> val
      {:commit, val} -> val
      {:ignore, _} -> nil
      _ -> nil
    end
  end

  def put_tenant(id, key, value, type \\ nil) do
    key_str = to_string(id) <> ":" <> to_string(key)
    inferred_type = type || infer_type(value)
    string_value = serialize_value(value, inferred_type)

    attrs = %{key: to_string(key), value: string_value, type: inferred_type}

    result =
      case Ash.get(Organization, [key: to_string(key)], tenant: id, not_found_error?: false) do
        nil ->
          Organization
          |> Ash.Changeset.for_create(:create, attrs, tenant: id)
          |> Ash.create()

        {:ok, nil} ->
          Organization
          |> Ash.Changeset.for_create(:create, attrs, tenant: id)
          |> Ash.create()

        {:ok, existing} ->
          existing
          |> Ash.Changeset.for_update(:update, attrs)
          |> Ash.update()
      end

    case result do
      {:ok, config} ->
        parsed_val = cast_value(config.value, config.type)
        Cachex.put(@tenant_cache_name, key_str, parsed_val)
        {:ok, parsed_val}

      error ->
        error
    end
  end

  def get_tenant(id, gateway_type, :gateway) do
    key_str = to_string(id) <> ":gateway:" <> to_string(gateway_type)

    result =
      Cachex.fetch(@tenant_cache_name, key_str, fn _key ->
        case Ash.get(Gateway, [gateway_type: gateway_type], not_found_error?: false) do
          {:ok, nil} -> {:ignore, nil}
          nil -> {:ignore, nil}
          {:ok, config} -> {:commit, config}
          config -> {:commit, config}
        end
      end)

    case result do
      {:ok, val} -> val
      {:commit, val} -> val
      {:ignore, _} -> nil
      _ -> nil
    end
  end

  defp cast_value(val, "integer"), do: String.to_integer(val)
  defp cast_value(val, "float"), do: String.to_float(val)
  defp cast_value(val, "map"), do: Jason.decode!(val)
  defp cast_value("true", "boolean"), do: true
  defp cast_value("false", "boolean"), do: false
  defp cast_value(val, "atom"), do: String.to_existing_atom(val)
  defp cast_value(val, _string), do: val

  defp serialize_value(value, _type) when is_map(value) or is_list(value),
    do: Jason.encode!(value)

  defp serialize_value(val, "atom"), do: to_string(val)
  defp serialize_value(:atom, _), do: "atom"
  defp serialize_value(value, :boolean), do: to_string(value)
  defp serialize_value(value, "boolean"), do: to_string(value)
  defp serialize_value(value, :integer), do: to_string(value)
  defp serialize_value(value, "integer"), do: to_string(value)
  defp serialize_value(value, :float), do: to_string(value)
  defp serialize_value(value, "float"), do: to_string(value)
  defp serialize_value(value, :map), do: Jason.encode!(value)
  defp serialize_value(value, "map"), do: Jason.encode!(value)
  defp serialize_value(value, _), do: to_string(value)

  defp infer_type(val) when is_integer(val), do: "integer"
  defp infer_type(val) when is_float(val), do: "float"
  defp infer_type(val) when is_boolean(val), do: "boolean"
  defp infer_type(val) when is_atom(val), do: "atom"
  defp infer_type(val) when is_map(val), do: "map"
  defp infer_type(_), do: "string"
end
