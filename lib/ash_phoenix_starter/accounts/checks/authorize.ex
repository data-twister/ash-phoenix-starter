defmodule AshPhoenixStarter.Accounts.Checks.Authorize do
  use Ash.Policy.SimpleCheck
  require Ash.Query

  @impl true
  def describe(_opts), do: "Authorize User Access Group"

  @doc """
  Returns true to authorize or false to deny access
  If actor is not provided, then deny access by returning false
  """
  @impl true
  def match?(nil = _actor, _context, _opts), do: false
  def match?(actor, context, _options), do: can?(actor, context)

  # Confirms if the actor has required permissions using our reusable can/3 function
  defp can?(actor, context) do
    resource = context.resource
    action_name = context.subject.action.name

    can(actor, resource, action_name)
  end

  # Public or private can/3 helper
  def can(nil, _module, _action), do: false

  def can(actor, module, action) when is_atom(action) do
    cond do
      is_current_team_owner?(actor) -> true
      true -> check_database_permissions(actor, module, action)
    end
  end

  def can(actor, module, action) when is_binary(action) do
    can(actor, module, String.to_existing_atom(action))
  end

  # Confirms if the actor is the owner of the current team
  defp is_current_team_owner?(actor) do
    AshPhoenixStarter.Accounts.Team
    |> Ash.Query.filter(owner_user_id == ^actor.id)
    |> Ash.Query.filter(domain == ^actor.current_team)
    |> Ash.exists?()
  end

  # Confirms if the actor has required permissions on the database
  defp check_database_permissions(actor, module, action_name) do
    short_name = Ash.Resource.Info.short_name(module)

    AshPhoenixStarter.Accounts.UserGroup
    |> Ash.Query.filter(user_id == ^actor.id)
    |> Ash.Query.filter(group.permissions.action == ^action_name)
    |> Ash.Query.filter(group.permissions.resource == ^short_name)
    |> Ash.exists?(tenant: actor.current_team, authorize?: false)
  end
end
