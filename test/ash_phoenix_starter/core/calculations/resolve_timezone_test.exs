defmodule AshPhoenixStarter.Core.Calculations.ResolveTimezoneTest do
  use ExUnit.Case, async: false

  alias AshPhoenixStarter.Cache.TimezoneResolution
  alias AshPhoenixStarter.Core.Calculations.ResolveTimezone

  setup do
    # Start :timezone_resolution_cache if not already started in test env
    unless Process.whereis(:timezone_resolution_cache) do
      start_supervised!({TimezoneResolution, name: :timezone_resolution_cache})
    end

    TimezoneResolution.delete_all()

    previous_req_opts = Application.get_env(:ash_phoenix_starter, :timezone_req_options)

    on_exit(fn ->
      if previous_req_opts do
        Application.put_env(:ash_phoenix_starter, :timezone_req_options, previous_req_opts)
      else
        Application.delete_env(:ash_phoenix_starter, :timezone_req_options)
      end
    end)

    :ok
  end

  describe "calculate/3" do
    test "returns pre-saved :cached_timezone immediately without cache or API lookup" do
      records = [
        %{cached_timezone: "America/Phoenix", latitude: nil, longitude: nil},
        %{cached_timezone: "Europe/Berlin", latitude: 52.52, longitude: 13.405}
      ]

      assert ["America/Phoenix", "Europe/Berlin"] =
               ResolveTimezone.calculate(records, [], %{})
    end

    test "returns nil when coordinates are missing" do
      records = [
        %{cached_timezone: nil, latitude: nil, longitude: nil},
        %{latitude: 32.2226, longitude: nil}
      ]

      assert [nil, nil] = ResolveTimezone.calculate(records, [], %{})
    end

    test "normalizes coordinates to 3 decimal places and serves hits from Nebulex cache" do
      # Seed cache for Tucson, AZ rounded coordinates {32.223, -110.975}
      TimezoneResolution.put({32.223, -110.975}, "America/Phoenix")

      # Slightly jittered GPS readings within ~10m should hit the same cached entry
      records = [
        %{latitude: 32.22261, longitude: -110.97471},
        %{latitude: 32.22319, longitude: -110.97539}
      ]

      assert ["America/Phoenix", "America/Phoenix"] =
               ResolveTimezone.calculate(records, [], %{})
    end

    test "supports Decimal coordinates" do
      TimezoneResolution.put({40.713, -74.006}, "America/New_York")

      records = [
        %{latitude: Decimal.new("40.7128"), longitude: Decimal.new("-74.0060")}
      ]

      assert ["America/New_York"] = ResolveTimezone.calculate(records, [], %{})
    end

    test "falls back to TimeAPI via Req and caches the resolved timezone" do
      Req.Test.stub(TimeApiStub, fn conn ->
        assert conn.request_path == "/api/TimeZone/coordinate"
        Req.Test.json(conn, %{"timeZone" => "Asia/Tokyo"})
      end)

      Application.put_env(:ash_phoenix_starter, :timezone_req_options,
        plug: {Req.Test, TimeApiStub}
      )

      records = [%{latitude: 35.6762, longitude: 139.6503}]

      assert ["Asia/Tokyo"] = ResolveTimezone.calculate(records, [], %{})
      assert TimezoneResolution.get({35.676, 139.65}) == "Asia/Tokyo"
    end

    test "returns nil gracefully when external API returns an error status" do
      Req.Test.stub(TimeApiErrorStub, fn conn ->
        Plug.Conn.send_resp(conn, 503, "Service Unavailable")
      end)

      Application.put_env(:ash_phoenix_starter, :timezone_req_options,
        plug: {Req.Test, TimeApiErrorStub}
      )

      records = [%{latitude: 51.5074, longitude: -0.1278}]

      assert [nil] = ResolveTimezone.calculate(records, [], %{})
      assert TimezoneResolution.get({51.507, -0.128}) == nil
    end
  end
end
