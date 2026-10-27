defmodule AshPhoenixStarter.Accounts.User.Changes.AddToOrganization do
  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    changeset
    |> Ash.Changeset.after_action(&add_user_current_organization(&1, &2, context))
    |> Ash.Changeset.after_action(&add_user_to_organization(&1, &2, context))
  end

  @impl Ash.Resource.Change
  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end

  defp add_user_current_organization(_changeset, user, context) do
    Ash.update(
      user,
      %{organization: context.actor.current_organization},
      action: :set_current_organization,
      authorize?: false
    )
  end

  defp add_user_to_organization(_changeset, user, context) do
    require Ash.Query

    actor_organization =
      AshPhoenixStarter.Accounts.Organization
      |> Ash.Query.filter(domain == ^context.actor.current_organization)
      |> Ash.read_first!(Ash.Context.to_opts(context))

    {:ok, _user_organization} =
      Ash.create(
        AshPhoenixStarter.Accounts.UserOrganization,
        %{user_id: user.id, organization_id: actor_organization.id},
        Ash.Context.to_opts(context)
      )

    {:ok, user}
  end
end
