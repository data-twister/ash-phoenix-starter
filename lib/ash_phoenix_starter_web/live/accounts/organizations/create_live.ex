defmodule AshPhoenixStarterWeb.Accounts.Organizations.CreateLive do
  use AshPhoenixStarterWeb, :live_view

  on_mount {AshPhoenixStarterWeb.LiveUserAuth, :live_user_required}

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.account_organizations flash={@flash} current_user={@current_user} uri={@uri}>
      <.form for={@form} phx-change="validate" phx-submit="save" id="user-organizations-form">
        <.render_ash_form_errors form={@form} />
        
    <!-- Member Identification Section -->
        <div class=" p-6 rounded-lg border border-gray-200">
          <h2 class="text-2xl font-semibold text-gray-700 mb-4">{gettext("Create new organization")}</h2>
          <.input
            field={@form[:name]}
            label={gettext("Organization Name")}
            required
          />
          <.input
            field={@form[:domain]}
            label={gettext("Domain")}
            type="text"
            aria-describedby="Unique Identifier"
          />
        </div>

        <.button>{gettext("Create new organization")}</.button>
      </.form>
    </Layouts.account_organizations>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket
    |> assign(:resource, AshPhoenixStarter.Accounts.Organization)
    |> assign_query_opts()
    |> assign_attributes()
    |> assign_form()
    |> ok()
  end
end
