defmodule AshPhoenixStarterWeb.SEO do
  use AshPhoenixStarterWeb, :verified_routes
  alias AshPhoenixStarterWeb.Config

  use SEO,
    json_library: Jason,
    # a function reference will be called with a conn during render
    # arity 1 will be passed the conn, arity 0 is also supported.
    site: &__MODULE__.site_config/1,
    open_graph:
      SEO.OpenGraph.build(
        description: Config.site_description(),
        site_name: Config.site_name(),
        locale: Config.site_default_locale()
      ),
    facebook: SEO.Facebook.build(app_id: Config.facebook_app_id()),
    twitter:
      SEO.Twitter.build(
        site: Config.twitter_site_name(),
        site_id: Config.twitter_site_id(),
        creator: Config.twitter_site_creator(),
        creator_id: Config.twitter_site_creator_id(),
        card: :summary
      )

  # Or arity 0 is also supported, which can be great if you're using
  # Phoenix verified routes and don't need the conn to generate paths.
  def site_config(conn) do
    SEO.Site.build(
      title_prefix: Config.site_title_prefix(),
      title_suffix: Config.site_default_suffix(),
      default_title: Config.site_default_title(),
      description: Config.site_default_description(),
      theme_color: Config.site_default_theme_color(),
      windows_tile_color: Config.site_default_windows_tile_color(),
      mask_icon_color: Config.site_default_mask_icon_color(),
      mask_icon_url: static_url(conn, "/images/safari-pinned-tab.svg"),
      manifest_url: url(conn, ~p"/site.webmanifest"),
      google_site_verification: Config.google_site_verification()
    )
  end
end
