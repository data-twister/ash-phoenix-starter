defmodule AshPhoenixStarter.Accounts.Invitation.Preparations.ForCurrentOrganization do
  use Ash.Resource.Preparation

  def prepare(query, _options, %{actor: nil}), do: query

  def prepare(query, _opts, context) do
    %{current_organization: organization} = context.actor
    Ash.Query.filter(query, organization == ^organization)
  end
end
