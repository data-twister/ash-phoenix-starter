defmodule AshPhoenixStarterWeb.HelpersTest do
  use ExUnit.Case, async: true

  alias AshPhoenixStarterWeb.Helpers
  alias AshPhoenixStarter.Accounts.User

  @moduledoc """
  Tests for user-related functions in the Accounts context.
  """

  describe "is_super_user?/1" do
    setup do
      # Temporarily set the super_users config for testing
      original_super_users = Application.get_env(:AshPhoenixStarter, :super_users, [])
      Application.put_env(:AshPhoenixStarter, :super_users, ["super@example.com"])

      on_exit(fn ->
        Application.put_env(:AshPhoenixStarter, :super_users, original_super_users)
      end)
    end

    test "returns true if the user's email is in the super_users config" do
      user = %User{email: "super@example.com"}
      assert Helpers.is_super_user?(user)
    end

    test "returns false if the user's email is not in the super_users config" do
      user = %User{email: "regular@example.com"}
      refute Helpers.is_super_user?(user)
    end

    test "handles nil email gracefully" do
      user = %User{email: nil}
      refute Helpers.is_super_user?(user)
    end
  end

  describe "impersonated?/1" do
    test "confirms if user is impersonated or not" do
      user = Map.put(%User{}, :impersonated?, true)
      assert Helpers.impersonated?(user) == true
    end

    test "denies if users is not impersonated" do
      refute Helpers.impersonated?(%User{})
    end
  end
end
