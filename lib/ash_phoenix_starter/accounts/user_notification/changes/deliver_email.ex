# lib/AshPhoenixStarter/accounts/user_notification/changes/deliver_email.ex
defmodule AshPhoenixStarter.Accounts.UserNotification.Changes.DeliverEmail do
  use Ash.Resource.Change
  require Logger

  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.change_attribute(:processed, true)
    |> Ash.Changeset.after_action(&enqueue_email_job/2)
  end

  def atomic?(), do: true

  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end

  defp enqueue_email_job(_changeset, notification) do
    %{recipient_user_id: user_id, id: notification_id} = notification

    # 1. Safely look up the recipient user to get their email address
    case AshPhoenixStarter.Accounts.User |> Ash.get(user_id, authorize?: false) do
      {:ok, recipient} ->
        # 2. Structure the payload to match your existing EmailSender worker args
        job_args = %{
          "params" => %{
            "to" => to_string(recipient.email),
            "subject" => notification.subject,
            "body" => notification.body,
            # Optional fallback text layout structure
            "text" => strip_html(notification.body)
          }
        }

        # 3. Schedule the worker background task
        job_args
        |> AshPhoenixStarter.Workers.EmailSender.new()
        |> Oban.insert()
        |> case do
          {:ok, _job} ->
            {:ok, notification}

          {:error, reason} ->
            Logger.error(
              "Failed to enqueue email for notification #{notification_id}: #{inspect(reason)}"
            )

            {:ok, notification}
        end

      {:error, %Ash.Error.Query.NotFound{}} ->
        Logger.warning(
          "Skipped enqueuing email notification #{notification_id}. Recipient user #{user_id} not found."
        )

        {:ok, notification}

      {:error, reason} ->
        Logger.error(
          "Error looking up recipient for notification #{notification_id}: #{inspect(reason)}"
        )

        {:ok, notification}
    end
  end

  # Tiny helper to make sure text_body isn't completely empty if it's parsed via HTML layout strings
  defp strip_html(nil), do: ""

  defp strip_html(html) do
    html
    |> String.replace(~r/<[^>]*>/, "")
    |> String.trim()
  end
end
