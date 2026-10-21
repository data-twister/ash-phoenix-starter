# lib/AshPhoenixStarter/workers/email_sender.ex
defmodule AshPhoenixStarter.Workers.EmailSender do
  use Oban.Worker, queue: :default
  import Swoosh.Email

  @impl Oban.Worker
  def perform(job) do
    params = job.args["params"]

    new()
    |> from({"AshPhoenixStarter", "no-reply@AshPhoenixStarter.com"})
    |> to(params["to"] |> to_string())
    |> subject(params["subject"])
    |> html_body(params["body"])
    |> text_body(params["text"])
    |> AshPhoenixStarter.Mailer.deliver!()

    :ok
  end
end