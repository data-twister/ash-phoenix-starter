defmodule AshPhoenixStarterWeb.Accounts.Organizations.OrganizationsLive do
  use AshPhoenixStarterWeb, :live_view
  on_mount {AshPhoenixStarterWeb.LiveUserAuth, :live_user_required}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.account_organizations flash={@flash} current_user={@current_user} uri={@uri}>
      <Cinder.Table.table query={get_query(@current_user)}>
        <:col :let={organization} field="Name" filter>{organization.name}({organization.domain})</:col>
        <:col :let={organization}>
          <.button
            :if={organization.domain !== @current_user.current_organization}
            id={"organization-#{organization.id}"}
            phx-click={"change-to-#{organization.domain}"}
          >
            <.icon name="hero-arrows-right-left" class="w-5 h-5" /> {gettext("Switch")}
          </.button>
        </:col>
      </Cinder.Table.table>
    </Layouts.account_organizations>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("change-to-" <> organization, _params, socket) do
    case switch_organization_to(organization, socket.assigns) do
      {:ok, _user} ->
        socket
        |> redirect(to: ~p"/accounts/organizations")
        |> put_flash(:info, "Organization changed")
        |> noreply()

      _error ->
        noreply(socket)
    end
  end

  defp switch_organization_to(organization, %{current_user: current_user}) do
    current_user
    |> Ash.Changeset.for_update(:switch_organization_to, %{organization: organization}, authorize?: false)
    |> Ash.update()
  end

  defp get_query(%{id: user_id}) do
    require Ash.Query
    Ash.Query.filter(AshPhoenixStarter.Accounts.Organization, users.id == ^user_id)
  end
end
