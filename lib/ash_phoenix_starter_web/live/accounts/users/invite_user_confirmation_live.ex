# lib/AshPhoenixStarter_web/live/accounts/users/user_invitations_live/invite_user_live.ex
defmodule AshPhoenixStarterWeb.Accounts.Users.UserInvitationsLive.InviteUserConfirmationLive do
  use AshPhoenixStarterWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.account_users flash={@flash} current_user={@current_user} uri={@uri}>
      <div class="max-w-2xl mx-auto p-6 bg-white rounded-lg border border-gray-200 shadow-sm mt-8">
        <div class="border-b border-gray-100 pb-4 mb-6">
          <h3 class="text-xl font-semibold leading-none tracking-tight text-gray-900">
            {gettext("Invite a new member to your team")}
          </h3>

          <p class="text-sm text-gray-500 mt-2">
            {gettext(
              "An invitation containing secure confirmation links will be delivered immediately to the email address provided below."
            )}
          </p>
        </div>

        <.form
          for={@form}
          phx-change="validate"
          phx-submit="save"
          id="standalone-invite-form"
          class="space-y-8 bg-white"
        >
          <.render_ash_form_errors form={@form} />
          <div class="space-y-4">
            <.input
              field={@form[:email]}
              type="email"
              label={gettext("New user Email")}
              placeholder="e.g. coworker@company.com"
              required
            />
            <.input
              field={@form[:group_id]}
              type="select"
              options={@access_groups}
              label={gettext("Select Access Group")}
              required
            />
          </div>

          <div class="flex justify-end gap-3 mt-6 pt-4 border-t border-gray-100">
            <.link
              navigate={~p"/accounts/users/invitations"}
              class="text-sm font-semibold leading-6 text-gray-900 flex items-center px-4 hover:bg-gray-50 rounded-lg"
            >
              {gettext("Cancel")}
            </.link>
            <.button variant="primary" type="submit" class="flex items-center gap-2">
              {gettext("Send Invitation")} <.icon name="hero-paper-airplane-solid" class="h-4 w-4" />
            </.button>
          </div>
        </.form>
      </div>
    </Layouts.account_users>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    socket
    |> assign(:access_groups, load_access_groups(actor))
    |> assign_invite_form(actor)
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    socket
    |> assign(:form, form)
    |> noreply()
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _invitation} ->
        socket
        |> put_flash(
          :info,
          gettext("Invitation sent with confirmation instructions successfully.")
        )
        |> redirect(to: ~p"/accounts/users/invitations")
        |> noreply()

      {:error, form} ->
        socket
        |> assign(:form, form)
        |> noreply()
    end
  end

  defp assign_invite_form(socket, actor) do
    form =
      AshPhoenixStarter.Accounts.Invitation
      |> AshPhoenix.Form.for_create(:create, actor: actor)
      |> to_form()

    assign(socket, :form, form)
  end

  defp load_access_groups(actor) do
    AshPhoenixStarter.Accounts.Group
    |> Ash.read!(tenant: actor.current_team, authorize?: false)
    |> Enum.map(&{&1.name, &1.id})
  end
end
