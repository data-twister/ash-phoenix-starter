# lib/AshPhoenixStarter/accounts/invitation/changes/add_user_to_organization.ex
defmodule AshPhoenixStarter.Accounts.Invitation.Changes.AddUserToOrganization do
  @moduledoc """
  An Ash Resource Change that adds a user to a organization and permission group.

  This module handles the process of linking a user to a organization, setting their
  current organization, and adding them to a permission group after accepting an invitation.
  It uses Ash's seeding and querying capabilities for reliable data operations.
  """

  use Ash.Resource.Change
  require Ash.Query

  @doc """
  Registers an after_action callback to link the user to the organization after
  the changeset is processed.
  """
  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &link_user_to_organization/2)
  end

  @impl true
  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end

  @doc """
  Links a user to a organization and permission group based on the invitation.

  Retrieves or creates the user, associates them with the organization, sets the
  current organization, and adds them to the specified permission group.

  ## Parameters
    - _changeset: The Ash changeset (unused, kept for hook compatibility)
    - invitation: The invitation struct containing email, organization, and group_id

  ## Returns
    - {:ok, invitation} on successful linking
    - {:error, reason} if any operation fails
  """
  def link_user_to_organization(_changeset, invitation) do
    with {:ok, user} <- get_or_create_user(invitation),
         {:ok, _user_organization} <- add_user_to_organization(user.id, invitation.organization),
         {:ok, _user_updated} <- set_user_current_organization(user, invitation.organization),
         {:ok, _user_group} <- add_user_to_group(user.id, invitation.group_id, invitation.organization) do
      {:ok, invitation}
    else
      {:error, reason} ->
        {:error, "Failed to link user to organization: #{inspect(reason)}"}
    end
  end

  defp get_organization(organization_name) do
    AshPhoenixStarter.Accounts.Organization
    |> Ash.Query.filter(domain == ^organization_name)
    |> Ash.read_first(authorize?: false)
    |> case do
      {:ok, organization} -> {:ok, organization}
      {:error, reason} -> {:error, reason}
    end
  end

  defp add_user_to_organization(user_id, organization_name) do
    with {:ok, organization} <- get_organization(organization_name) do
      Ash.Seed.seed!(
        AshPhoenixStarter.Accounts.UserOrganization,
        %{user_id: user_id, organization_id: organization.id},
        tenant: organization_name
      )
      |> then(&{:ok, &1})
    end
  end

  defp set_user_current_organization(user, organization_name) do
    Ash.Seed.update!(user, %{current_organization: organization_name}, tenant: organization_name)
    |> then(&{:ok, &1})
  end

  defp add_user_to_group(user_id, group_id, organization_name) do
    Ash.Seed.seed!(
      AshPhoenixStarter.Accounts.UserGroup,
      %{user_id: user_id, group_id: group_id},
      tenant: organization_name
    )
    |> then(&{:ok, &1})
  end

  defp get_or_create_user(%{email: email, organization: organization_name}) do
    AshPhoenixStarter.Accounts.User
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_first(authorize?: false)
    |> case do
      {:ok, nil} -> create_user(email, organization_name)
      {:ok, user} -> {:ok, user}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_user(email, organization_name) do
    Ash.Seed.seed!(
      AshPhoenixStarter.Accounts.User,
      %{email: email, current_organization: organization_name},
      tenant: organization_name
    )
    |> then(&{:ok, &1})
  end
end
