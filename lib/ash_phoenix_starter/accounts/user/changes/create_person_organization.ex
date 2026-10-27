defmodule AshPhoenixStarter.Accounts.User.Changes.CreatePersonOrganization do
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    # Only create organization automatically for specific actions
    if changeset.action.name in [:register_with_password] do
      Ash.Changeset.after_action(changeset, &create_personal_organization/2)
    else
      changeset
    end
  end

  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end

  defp create_personal_organization(_changeset, user) do
    organization_count = Ash.count!(AshPhoenixStarter.Accounts.Organization) + 1
    organization_attrs = %{name: "Personal Organization", domain: "personal_organization_#{organization_count}"}

    {:ok, _organization} = Ash.create(AshPhoenixStarter.Accounts.Organization, organization_attrs, actor: user)
    {:ok, Map.put(user, :current_organization, organization_attrs.domain)}
  end
end
