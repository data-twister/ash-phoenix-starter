defmodule AshPhoenixStarter.Generators.User do
  use Ash.Generator
  alias AshPhoenixStarter.Accounts.User

  def user(opts \\ []) do
    changeset_generator(
      User,
      :seed_user,
      defaults: [
        email: sequence(:email, &"user_#{&1}@example.com"),
        password: "Passw0rd123!",
        password_confirmation: "Passw0rd123!"
      ],
      overrides: opts,
      authorize?: false
    )
  end
end
