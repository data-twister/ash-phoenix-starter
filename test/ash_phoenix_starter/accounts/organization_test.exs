defmodule AshPhoenixStarter.Accounts.OrganizationTest do
  use AshPhoenixStarterWeb.ConnCase
  require Ash.Query

  describe "Organization tests" do
    test "User organization can be created" do
      user = create_user()

      # Create a new organization for the user
      uuid = Ash.UUIDv7.generate()
      organization_count = Ash.count!(AshPhoenixStarter.Accounts.Organization) + 1
      organization_attrs = %{name: "Organization #{organization_count} #{uuid}", domain: "organization_#{organization_count}_#{uuid}"}

      {:ok, organization} = Ash.create(AshPhoenixStarter.Accounts.Organization, organization_attrs, actor: user)

      # New organization should be stored successfully.
      assert AshPhoenixStarter.Accounts.Organization
             |> Ash.Query.filter(domain == ^organization.domain)
             |> Ash.Query.filter(owner_user_id == ^organization.owner_user_id)
             |> Ash.exists?(authorize?: false)

      # New organization should be set as the current organization on the owner
      assert AshPhoenixStarter.Accounts.User
             |> Ash.Query.filter(id == ^user.id)
             |> Ash.Query.filter(current_organization == ^organization.domain)
             #  User resource has special policies for authorizations. We are skipping authorization by setting it to false
             |> Ash.exists?(authorize?: false)

      # New organization should be added to the organizations list of the owner
      assert AshPhoenixStarter.Accounts.User
             |> Ash.Query.filter(id == ^user.id)
             |> Ash.Query.filter(organizations.id == ^organization.id)
             |> Ash.exists?(authorize?: false)
    end
  end
end
