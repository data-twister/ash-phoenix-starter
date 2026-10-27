defmodule AshPhoenixStarter.Accounts.User.Notifiers.CreatePersonalOrganizationNotification do
  alias Ash.Notifier.Notification
  use Ash.Notifier

  def notify(%Notification{data: user, action: %{name: :register_with_password}}) do
    create_personal_organization(user)
  end

  def notify(%Notification{} = _notification), do: :ok

  defp create_personal_organization(user) do
    # Determine the count of existing organization and use it as a
    # suffix to the organization domain.
    organization_count = Ash.count!(AshPhoenixStarter.Accounts.Organization) + 1

    organization_attrs = %{
      name: "Personal Organization",
      domain: "personal_organization_#{organization_count}",
      owner_user_id: user.id
    }

    Ash.create!(AshPhoenixStarter.Accounts.Organization, organization_attrs)
  end
end
