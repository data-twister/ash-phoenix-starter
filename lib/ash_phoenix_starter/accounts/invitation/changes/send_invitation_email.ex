# lib/AshPhoenixStarter/accounts/invitation/changes/send_invitation_email.ex
defmodule AshPhoenixStarter.Accounts.Invitation.Changes.SendInvitationEmail do
  @moduledoc """
  An Ash Resource Change that sends an invitation email to a user.

  This module handles sending an email to invite a user to join a organization,
  including a link to accept the invitation. It uses Oban for asynchronous
  email delivery.
  """

  use Ash.Resource.Change
  use AshPhoenixStarterWeb, :verified_routes

  @doc """
  Registers an after_action callback to send the invitation email after
  the changeset is processed.
  """
  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &send_email/2)
  end

  @doc """
  Implements the atomic change hook for Ash to ensure atomic operations.
  """
  @impl true
  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end

  defp send_email(_changeset, invitation) do
    with {:ok, email_data} <- build_email_data(invitation),
         {:ok, _job} <- schedule_email(email_data) do
      {:ok, invitation}
    else
      {:error, reason} ->
        {:error, "Failed to send invitation email: #{inspect(reason)}"}
    end
  end

  defp build_email_data(%{email: email, token: token, organization: organization}) do
    message = build_email_body(email, token, organization)

    email_data = %{
      id: token,
      params: %{
        html_message: message,
        text_message: message,
        subject: "You're Invited to Join #{organization}",
        from: nil,
        to: email
      }
    }

    {:ok, email_data}
  end

  defp build_email_body(email, token, organization) do
    accept_url = url(~p"/accounts/users/invitations/#{organization}/#{token}/accept")

    """
    <p>Hello, #{email}!</p>
    <p>You've been invited to join the <strong>#{organization}</strong> organization.</p>
    <p>Please click the link below to accept the invitation:</p>
    <p><a href="#{accept_url}">Accept Invitation</a></p>
    <p>If you believe this invitation was sent in error, please contact the organization administrator.</p>
    """
  end

  defp schedule_email(email_data) do
    email_data
    |> AshPhoenixStarter.Workers.EmailSender.new()
    |> Oban.insert()
  end
end
