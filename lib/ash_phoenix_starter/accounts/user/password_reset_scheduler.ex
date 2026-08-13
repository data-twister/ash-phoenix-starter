defmodule AshPhoenixStarter.Accounts.PasswordResetScheduler do
  use GenServer
  require Logger

  @default_interval_minutes 5

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    schedule_tick()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:tick, state) do
    dispatch_triggers()
    schedule_tick()
    {:noreply, state}
  end

  defp schedule_tick do
    interval_ms = fetch_interval_ms()
    Process.send_after(self(), :tick, interval_ms)
  end

  defp fetch_interval_ms do
    minutes =
      case System.get_env("PASSWORD_CHECK_INTERVAL_MINUTES") do
        nil ->
          @default_interval_minutes

        val ->
          case Integer.parse(val) do
            {parsed, _} when parsed > 0 -> parsed
            _ -> @default_interval_minutes
          end
      end

    :timer.minutes(minutes)
  end

  defp dispatch_triggers do
    # 1. Fetch matching records using your resource's read action
    case AshPhoenixStarter.Accounts.User.list_empty_password_admins(authorize?: false) do
      {:ok, []} ->
        Logger.info("No records found matching the trigger criteria.")

      {:ok, users} ->
        # 2. Push them into AshOban so they get queued as individual background jobs
        case AshOban.run_triggers(users, :reset_empty_admin_password) do
          results when is_list(results) ->
            Logger.info("Successfully enqueued #{length(results)} jobs into Oban.")

          {:error, reason} ->
            Logger.error("Failed to enqueue AshOban triggers: #{inspect(reason)}")
        end

      {:error, reason} ->
        Logger.error("Failed to query records for trigger: #{inspect(reason)}")
    end
  end
end
