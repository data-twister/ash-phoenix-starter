defmodule AshPhoenixStarterWeb.Accounts.Organizations.OrganizationsLiveTest do
  use AshPhoenixStarterWeb.ConnCase

  describe "Organizations" do
    test "List organization", %{conn: conn} do
      user = create_user()

      {:ok, view, html} =
        conn
        |> login(user)
        |> live(~p"/accounts/organizations")

      assert html =~ "Loading..."
      assert render_async(view) =~ user.current_organization
    end

    test "Switch organization", %{conn: conn} do
      user = create_user()
      unique_id = String.replace(Ash.UUIDv7.generate(), "-", "_")
      params = %{name: "Organization #{unique_id}", domain: "organization_#{unique_id}"}

      {:ok, organization_2} = Ash.create(AshPhoenixStarter.Accounts.Organization, params, actor: user)

      {:ok, view, html} =
        conn
        |> login(user)
        |> live(~p"/accounts/organizations")

      assert html =~ "Loading..."
      assert render_async(view) =~ organization_2.name
      refute user.current_organization == organization_2.domain

      # Attempt to switch organization, then confirm the user current organization
      # matches the new organization after switch
      assert render_click(view, "change-to-#{organization_2.domain}", %{})

      require Ash.Query

      assert AshPhoenixStarter.Accounts.User
             |> Ash.Query.filter(current_organization == ^organization_2.domain)
             |> Ash.Query.filter(id == ^user.id)
             |> Ash.exists?(authorize?: false)
    end
  end
end
