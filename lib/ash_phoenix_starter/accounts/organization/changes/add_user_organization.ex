defmodule AshPhoenixStarter.Accounts.Organization.Changes.AddUserOrganization do
  @moduledoc """
  Link user to the organization via user_organizations relationship so that when
  we are listing owners organizations, this organization will be listed as well
  """

  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &associate_owner_to_organization/2)
  end

  defp associate_owner_to_organization(_changeset, organization) do
    AshPhoenixStarter.Accounts.UserOrganization
    |> Ash.Changeset.for_create(:create, %{user_id: organization.owner_user_id, organization_id: organization.id})
    |> Ash.create!()

    {:ok, organization}
  end
end
