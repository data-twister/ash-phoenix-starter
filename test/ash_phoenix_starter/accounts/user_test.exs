defmodule AshPhoenixStarter.Accounts.UserTest do
  use AshPhoenixStarterWeb.ConnCase
  require Ash.Query

  describe "User tests:" do
    test "User creation - creates personal organization automatically" do
      # Create a new user
      user_params = %{
        email: "john.tester@example.com",
        password: "12345678",
        password_confirmation: "12345678"
      }

      user =
        Ash.create!(
          AshPhoenixStarter.Accounts.User,
          user_params,
          action: :register_with_password,
          authorize?: false
        )

      # Confirm that the new user has a personal organization created for them automatically
      refute AshPhoenixStarter.Accounts.User
             |> Ash.Query.filter(id == ^user.id)
             |> Ash.Query.load(:groups)
             |> Ash.Query.filter(email == ^user_params.email)
             |> Ash.Query.filter(is_nil(current_organization))
             |> Ash.exists?(actor: user, authorize?: false)
    end

    test "User can be invited and be added to the organization" do
      user = create_user()

      {:ok, invited_user} =
        Ash.create(
          AshPhoenixStarter.Accounts.User,
          %{email: "invited_user@example.com"},
          action: :invite,
          actor: user,
          authorize?: false,
          load: :organizations
        )

      assert invited_user.current_organization == user.current_organization
      assert Enum.count(invited_user.organizations) == 1
    end
  end
end
