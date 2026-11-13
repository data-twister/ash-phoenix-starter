defmodule AshPhoenixStarterWeb.Menu do
  use Gettext, backend: AshPhoenixStarterWeb.Gettext
  use AshPhoenixStarterWeb, :html

    @doc """
  Matches exact paths as well as nested sub-routes (e.g. `/vendors/new` or `/vendors/:id/edit`).
  """
  def active_link?(%URI{path: current_path}, href) when is_binary(current_path) do
    link_path = URI.parse(href).path || href

    current_path == link_path or
      String.starts_with?(current_path, String.trim_trailing(link_path, "/") <> "/")
  end

  def active_link?(_, _), do: false


  @doc """
  Configure left menu in the application
  """
  def left_menu(current_user) do
    if AshPhoenixStarterWeb.Helpers.is_super_user?(current_user) do
      super_user_left()
    else
      non_super_user_left_menu()
    end
  end

  defp non_super_user_left_menu() do
    [
      %{
        title: gettext(""),
        links: [
          %{
            href: ~p"/dashboard",
            icon: "hero-chart-bar-solid",
            text: gettext("Dashboard")
          }
        ]
      },
      %{
        title: gettext("Supply Chain"),
        links: [
          %{
            href: ~p"/vendors",
            icon: "hero-truck",
            text: gettext("Vendors")
          },
          %{
            href: ~p"/merchants",
            icon: "hero-building-storefront",
            text: gettext("Merchants")
          },
          %{
            href: ~p"/products",
            icon: "hero-cube",
            text: gettext("Products")
          },
          %{
            href: ~p"/inventory/dashboard",
            icon: "hero-map-pin",
            text: gettext("Regional Inventory")
          }
        ]
      },
      %{
        title: gettext("Reports"),
        links: [
          %{
            href: ~p"/reports/graphs",
            icon: "hero-chart-pie",
            text: gettext("Graphs")
          },
          %{
            href: ~p"/reports/summaries",
            icon: "hero-bars-3-bottom-left",
            text: gettext("Summary")
          }
        ]
      },
      %{
        title: gettext("Accounting"),
        links: [
          %{
            href: ~p"/ledger/transfers",
            icon: "hero-arrows-right-left",
            text: gettext("Journal")
          },
          %{
            href: ~p"/ledger/journal",
            icon: "hero-document-text",
            text: gettext("Genearl Ledger")
          },
          %{
            href: ~p"/ledger/chart-of-accounts",
            icon: "hero-table-cells",
            text: gettext("Chart of Accounts")
          }
        ]
      },
      %{
        title: gettext("Settings"),
        links: [
          %{
            href: "/accounts/organizations",
            icon: "hero-building-library",
            text: gettext("Organizations")
          },
          %{
            href: "/accounts/users",
            icon: "hero-users",
            text: gettext("Users")
          },
          %{
            href: "/accounts/groups",
            icon: "hero-user-group",
            text: gettext("User Groups")
          }
        ]
      }
    ]
  end

  defp super_user_left() do
    [
      %{
        title: gettext(""),
        links: [
          %{
            href: ~p"/dashboard",
            icon: "hero-chart-bar-solid",
            text: gettext("Dashboard")
          }
        ]
      },
      %{
        title: gettext("Supply Chain"),
        links: [
          %{
            href: ~p"/vendors",
            icon: "hero-truck",
            text: gettext("Vendors")
          },
          %{
            href: ~p"/merchants",
            icon: "hero-building-storefront",
            text: gettext("Merchants")
          },
          %{
            href: ~p"/products",
            icon: "hero-cube",
            text: gettext("Products")
          },
          %{
            href: ~p"/inventory/dashboard",
            icon: "hero-map-pin",
            text: gettext("Regional Inventory")
          }
        ]
      },
      %{
        title: gettext("Reports"),
        links: [
          %{
            href: ~p"/reports/graphs",
            icon: "hero-chart-pie",
            text: gettext("Graphs")
          },
          %{
            href: ~p"/reports/summaries",
            icon: "hero-bars-3-bottom-left",
            text: gettext("Summary")
          }
        ]
      },
      %{
        title: gettext("Settings"),
        links: [
          %{
            href: "/accounts/organizations",
            icon: "hero-building-library",
            text: gettext("Organizations")
          },
          %{
            href: "/accounts/users",
            icon: "hero-users",
            text: gettext("Users")
          }
        ]
      }
    ]
  end
end
