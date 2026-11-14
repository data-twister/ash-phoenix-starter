# lib/AshPhoenixStarter/workers/email_sender.ex
defmodule AshPhoenixStarter.Workers.EmailSender do
  use Oban.Worker, queue: :default
  import Swoosh.Email

  alias AshPhoenixStarter.Accounts.ObanActorPersister

    @doc """
  Helper to build a new EmailSender job while serializing the actor.

  ## Example
      %{params: email_params}
      |> EmailSender.new_with_actor(current_user)
      |> Oban.insert()
  """
  def new_with_actor(args, actor \\ nil, opts \\ []) do
    args
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
    |> Map.put("actor", ObanActorPersister.store(actor))
    |> new(opts)
  end

  @impl Oban.Worker
  def perform(job) do
    domain = AshPhoenixStarterWeb.Endpoint.host()
    app_name = Application.get_env(:ash_phoenix_starter, :product_name, AshPhoenixStarter.app_name())

    params = job.args["params"]

    new()
    |> from({app_name, "no-reply@#{domain}"})
    |> to(params["to"] |> to_string())
    |> subject(params["subject"])
    |> html_body(params["body"])
    |> text_body(params["text"])
    |> AshPhoenixStarter.Mailer.deliver!()

    :ok
  end
end
