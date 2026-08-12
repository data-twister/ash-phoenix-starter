defmodule AshPhoenixStarterWeb.LiveTracking do
  defmacro __using__(opts) do
    quote do
      @presence_topic "users:online"

      socket = Keyword.get(unquote(opts), :socket, nil)

      on_mount({AshPhoenixStarterWeb.LiveTracking, :track_presence})

      @impl true
      def handle_info(%{event: "presence_diff", payload: _payload}, socket) do
        socket = assign(socket, :online_users, list_online_users())
        {:noreply, socket}
      end

      defp list_online_users() do
        AshPhoenixStarterWeb.Presence.list(@presence_topic)
      end

      defp list_registered_users() do
        AshPhoenixStarterWeb.Presence.list(@presence_topic)
        |> Enum.reject(fn {user_id, meta} ->
          user_id == "guest"
        end)
        |> Enum.map(fn {user_id, meta} -> {user_id, meta} end)
      end

      defp list_guest_users() do
        AshPhoenixStarterWeb.Presence.list(@presence_topic)
        |> Enum.filter(fn {user_id, meta} ->
          user_id == "guest"
        end)
        |> Enum.map(fn {user_id, meta} -> {user_id, meta} end)
      end

      defp format_timestamp(nil), do: ""

      defp format_timestamp(unix_timestamp)
           when is_integer(unix_timestamp) and unix_timestamp > 0 do
        post_dt = DateTime.from_unix!(unix_timestamp)
        post_date = DateTime.to_date(post_dt)
        today = Date.utc_today()

        day_name = Calendar.strftime(post_dt, "%a") |> String.downcase()
        time_str = Calendar.strftime(post_dt, "%I:%M %p") |> String.downcase()

        cond do
          post_date == today ->
            "#{day_name}, today #{time_str}"

          post_date == Date.add(today, -1) ->
            "#{day_name}, yesterday #{time_str}"

          true ->
            date_str = Calendar.strftime(post_dt, "%b %d") |> String.downcase()
            "#{day_name}, #{date_str}, #{time_str}"
        end
      end

      defp format_timestamp(_), do: ""
    end
  end

  def on_mount(:track_presence, _params, _session, socket) do
    current_user = socket.assigns[:current_user]
    presence_topic = "users:online"

    if Phoenix.LiveView.connected?(socket) do
      Phoenix.PubSub.subscribe(AshPhoenixStarter.PubSub, presence_topic)

      user_key = if current_user, do: to_string(current_user.id), else: "guest"

      user_meta =
        if current_user do
          %{
            online_at: System.system_time(:second)
          }
        else
          %{
            online_at: System.system_time(:second)
          }
        end

      {:ok, _ref} =
        AshPhoenixStarterWeb.Presence.track(self(), presence_topic, user_key, user_meta)
    end

    {:cont, socket}
  end
end
