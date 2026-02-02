defmodule AshPhoenixStarter.Accounts.Checks.Authorize do
  use Ash.Policy.SimpleCheck
  require Ash.Query

  @impl true
  def describe(_opts), do: "Authorize User Access Group"

  @doc """
  Returns true to authorize or false to deny access
  If actor is not provide, then deny access by returning false
  """
  @impl true

  def match?(nil = _actor, _context, _opts), do: false
  def match?(actor, context, _options), do: authorized?(actor, context)

  # """
  # 1. If the actor is the team owner, then authorize since he's the owner
  # 2. If none of the above, then check if the user has permission on the database
  # """
  defp authorized?(actor, context) do
    cond do
      is_current_team_owner?(actor) -> true
      true -> can?(actor, context)
    end
  end

  # Confirms if the actor is the owner of the current team
  defp is_current_team_owner?(actor) do
    AshPhoenixStarter.Accounts.Team
    |> Ash.Query.filter(owner_user_id == ^actor.id)
    |> Ash.Query.filter(domain == ^actor.current_team)
    |> Ash.exists?()
  end

  # Confirms if the actor has required permissions to perform the current
  # action on the current resource
  defp can?(actor, context) do
    short_name = Ash.Resource.Info.short_name(context.resource)

    SocialFund.Accounts.UserGroup
    |> Ash.Query.filter(user_id == ^actor.id)
    |> Ash.Query.filter(group.permissions.action == ^context.subject.action.name)
    |> Ash.Query.filter(group.permissions.resource == ^short_name)
    |> Ash.exists?(tenant: actor.current_team, authorize?: false)
  end
end
