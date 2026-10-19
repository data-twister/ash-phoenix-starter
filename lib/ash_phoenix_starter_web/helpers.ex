defmodule AshPhoenixStarterWeb.Helpers do
  alias AshPhoenixStarter.Accounts.User

  @doc """
  Confirms if a user is a among super users
  """
  @spec is_super_user?(User.t()) :: boolean()
  def is_super_user?(user) do
    super_users = Application.get_env(:AshPhoenixStarter, :super_users, [])
    to_string(user.email) in super_users
  end

  @doc """
  Confirm if the users is impersonative
  """
  @spec impersonated?(User.t()) :: boolean()
  def impersonated?(user), do: Map.get(user, :impersonated?, false)


  def get_currency_atom(country_code) when is_binary(country_code) do
    # 1. "us" -> "US"
    # 2. "US" -> :US
   territory_atom = country_code |> String.upcase() |> String.to_existing_atom()
    
    # 3. Fetches the active currency atom (e.g., :USD)
   Cldr.Currency.current_currency_for_territory(territory_atom)
  rescue
   ArgumentError -> {:error, :invalid_country_code}
 end


 alias AshPhoenixStarter.Settings.Manager

  @doc """
  Retrieves the CDN host using the SettingsManager (which handles database fallback
  and ConCache caching internally). Falls back to the local site endpoint URL if
  no CDN host setting is configured.
  """
  def cdn_host(tenant_id \\ nil) do
    # You can support tenant-specific keys or a global key via your SettingsManager
    setting_key = tenant_key(tenant_id, "cdn_host")

    Manager.get(setting_key) ||
      Manager.get("cdn_host") ||
      local_site_url()
  end

  def static_url(path, tenant_id \\ nil) do
    "https://#{cdn_host(tenant_id)}#{path}"
  end

  # --- Private Helpers ---

  defp tenant_key(nil, key), do: key
  defp tenant_key(tenant_id, key), do: "tenant:#{tenant_id}:#{key}"

  defp local_site_url do
    endpoint_config = Application.get_env(:AshPhoenixStarter, AshPhoenixStarterWeb.Endpoint)
    url_config = Keyword.get(endpoint_config, :url, [])
    Keyword.get(url_config, :host, "localhost")
  end
end
end
