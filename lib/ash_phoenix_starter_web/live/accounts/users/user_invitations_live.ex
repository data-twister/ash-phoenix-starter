# lib/AshPhoenixStarter_web/live/accounts/users/user_invitations_live.ex
defmodule AshPhoenixStarterWeb.Accounts.Users.UserInvitationsLive do
  use AshPhoenixStarterWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <AshPhoenixStarterWeb.Components.InviteNewUserForm.render actor={@current_user} id="invitation_live" />
    <Cinder.Table.table
      resource={AshPhoenixStarter.Accounts.Invitation}
      actor={@current_user}
      id="user-invitations-table"
      page_size={20}
    >
      <:col :let={row} label="Email" field="email" filter sort>
        {Phoenix.Naming.humanize(row.email)}
      </:col>

      <:col :let={row} label="Status" field="status" filter sort>
        {Phoenix.Naming.humanize(row.status)}
      </:col>

      <:col :let={row} label="Organization">{Phoenix.Naming.humanize(row.organization)}</:col>
    </Cinder.Table.table>
    """
  end

  @impl true
  def mount(_params, _sessions, socket) do
    socket
    |> assign(:page_title, gettext("User Invitations"))
    |> ok()
  end
end
