defmodule AshPhoenixStarter.Accounts.UserNotification.Changes.SendEmail do
  use Ash.Resource.Change
  import Swoosh.Email

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &send_email/2)
  end

  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end

  defp send_email(_changeset, notification) do
    domain = AshPhoenixStarterWeb.Endpoint.host()

    new()
    |> from({"noreply", "noreply@#{domain}"})
    |> to("noreply@#{domain}")
    |> subject(notification.subject || "New Notification")
    |> html_body(notification.body)
    |> AshPhoenixStarter.Mailer.deliver!()

    {:ok, notification}
  end
end
