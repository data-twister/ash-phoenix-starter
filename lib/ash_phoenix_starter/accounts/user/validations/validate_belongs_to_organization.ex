defmodule AshPhoenixStarter.Accounts.User.Validations.ValidateBelongsToOrganization do
  use Ash.Resource.Validation

  @impl Ash.Resource.Validation
  def supports(_), do: [Ash.Query]

  @impl Ash.Resource.Validation
  def validate(subject, _opts, _context) do
    if user_belongs_to_organization?(subject) do
      :ok
    else
      {:error, field: :current_organization, message: "User must belong to the organization"}
    end
  end

  @impl Ash.Resource.Validation
  def atomic(subject, opts, context) do
    validate(subject, opts, context)
  end

  defp user_belongs_to_organization?(subject) do
    AshPhoenixStarter.Accounts.User
    |> Ash.Query.filter(organizations.domain == ^subject.arguments.organization)
    |> Ash.Query.filter(id == ^subject.data.id)
    |> Ash.exists?(authorize?: false)
  end
end
