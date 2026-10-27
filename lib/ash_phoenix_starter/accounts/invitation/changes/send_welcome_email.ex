# lib/AshPhoenixStarter/accounts/invitation/changes/send_welcome_email.ex
defmodule AshPhoenixStarter.Accounts.Invitation.Changes.SendWelcomeEmail do
  @moduledoc """
  An Ash Resource Change that sends a welcome email to a user.

  This module handles sending a welcome email with a magic link for signing in
  after a user accepts an invitation. It uses Oban for asynchronous email delivery.
  """

  use Ash.Resource.Change
  use AshPhoenixStarterWeb, :verified_routes

  @doc """
  Registers an after_action callback to send the welcome email after
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

  @doc """
  Sends a welcome email with a magic link for signing in.

  Builds the email content with a sign-in link and schedules it via the
  EmailSender worker.

  ## Parameters
    - _changeset: The Ash changeset (unused, kept for hook compatibility)
    - invitation: The invitation struct containing email, token, and organization

  ## Returns
    - {:ok, invitation} on successful email scheduling
    - {:error, reason} if email scheduling fails
  """
  def send_email(_changeset, invitation) do
    with {:ok, email_data} <- build_email_data(invitation),
         {:ok, _job} <- schedule_email(email_data) do
      {:ok, invitation}
    else
      {:error, reason} ->
        {:error, "Failed to send welcome email: #{inspect(reason)}"}
    end
  end

  defp build_email_data(%{email: email, token: token, organization: organization}) do
    message = build_email_body(email, token, organization)

    email_data = %{
      id: token,
      params: %{
        html_message: message,
        text_message: message,
        subject: "Welcome to #{organization}!",
        from: nil,
        to: email
      }
    }

    {:ok, email_data}
  end

  defp build_email_body(email, token, organization) do
    sign_in_url = url(~p"/auth/user/magic_link/?token=#{token}")

    """
    <p>Hello, #{email}!</p>
    <p>Welcome to the <strong>#{organization}</strong> organization!</p>
    <p>Please click the link below to sign in and get started:</p>
    <p><a href="#{sign_in_url}">Sign In</a></p>
    <p>If you have any issues, please contact the organization administrator.</p>
    """
  end

  defp schedule_email(email_data) do
    email_data
    |> AshPhoenixStarter.Workers.EmailSender.new()
    |> Oban.insert()
  end
end
