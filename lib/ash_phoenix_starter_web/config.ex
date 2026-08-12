defmodule AshPhoenixStarterWeb.Config do
  def endpoint_store(default \\ :cookie) do
    Application.get_env(:AshPhoenixStarter, :endpoint_store, default)
  end

  def endpoint_key(default \\ "_web_key") do
    Application.get_env(:AshPhoenixStarter, :endpoint_key, default)
  end

  def endpoint_signing_salt(default \\ "gTm6MBR2") do
    Application.get_env(:AshPhoenixStarter, :endpoint_signing_salt, default)
  end

  def endpoint_same_site(default \\ "Lax") do
    Application.get_env(:AshPhoenixStarter, :endpoint_same_site, default)
  end

  def ssl_domains(default \\ [{"example.com", "demo@example.com"}]) do
    Application.get_env(:AshPhoenixStarter, :ssl_endpoint_domain_info, default)
  end

  def ssl_port(default \\ 4002) do
    Application.get_env(:AshPhoenixStarter, :ssl_endpoint_port, default)
  end

  def site_author(default \\ "mithereal") do
    Application.get_env(:AshPhoenixStarter, :site_author, default)
  end

  def site_default_title(default \\ "") do
    Application.get_env(:AshPhoenixStarter, :site_default_title, default)
  end

  def site_default_suffix(default \\ "") do
    Application.get_env(:AshPhoenixStarter, :site_default_suffix, default)
  end

  def site_default_description(default \\ "") do
    Application.get_env(:AshPhoenixStarter, :site_default_description, default)
  end

  def site_default_theme_color(default \\ "#663399") do
    Application.get_env(:AshPhoenixStarter, :site_default_theme_color, default)
  end

  def site_themes_list(default \\ ["default"]) do
    Application.get_env(:AshPhoenixStarter, :site_themes_list, default)
  end

  def site_default_windows_tile_color(default \\ "#663399") do
    Application.get_env(:AshPhoenixStarter, :site_default_windows_tile_color, default)
  end

  def site_default_mask_icon_color(default \\ "#663399") do
    Application.get_env(:AshPhoenixStarter, :site_default_mask_icon_color, default)
  end

  def site_default_locale(default \\ "en_US") do
    Application.get_env(:AshPhoenixStarter, :site_default_locale, default)
  end

  def google_site_verification(default \\ "") do
    Application.get_env(:AshPhoenixStarter, :google_site_verification, default)
  end

  def site_title_prefix(default \\ "") do
    Application.get_env(:AshPhoenixStarter, :site_title_prefix, default)
  end

  ##
  def site_description(default \\ "") do
    Application.get_env(:AshPhoenixStarter, :site_description, default)
  end

  def site_name(default \\ "") do
    Application.get_env(:AshPhoenixStarter, :site_name, default)
  end

  def facebook_app_id(default \\ "") do
    Application.get_env(:AshPhoenixStarter, :facebook_app_id, default)
  end

  def twitter_site_name(default \\ "") do
    Application.get_env(:AshPhoenixStarter, :twitter_site_name, default)
  end

  def twitter_site_id(default \\ "") do
    Application.get_env(:AshPhoenixStarter, :twitter_site_id, default)
  end

  def twitter_site_creator(default \\ "") do
    Application.get_env(:AshPhoenixStarter, :twitter_site_creator, default)
  end

  def twitter_site_creator_id(default \\ "") do
    Application.get_env(:AshPhoenixStarter, :twitter_site_creator_id, default)
  end
end
