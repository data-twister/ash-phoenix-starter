defmodule AshPhoenixStarter.Accounts.Organization.Changes.SwitchActorOrganization do
  use Ash.Resource.Change

  def change(changeset, _organization, _context) do
    Ash.Changeset.after_action(changeset, &set_owner_current_organization/2)
  end

  # If the organization was created without assigning the current owner,  then skip
  # auto setting of the organization owner. It will be set manually later by
  # other means
  defp set_owner_current_organization(_changeset, %{owner_user_id: nil} = organization) do
    {:ok, organization}
  end

  defp set_owner_current_organization(_changeset, organization) do
    opts = [authorize?: false]

    {:ok, _user} =
      AshPhoenixStarter.Accounts.User
      |> Ash.get!(organization.owner_user_id, opts)
      |> Ash.Changeset.for_update(:set_current_organization, %{organization: organization.domain})
      |> Ash.update(opts)

    {:ok, organization}
  end
end
