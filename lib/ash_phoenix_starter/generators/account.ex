defmodule AshPhoenixStarter.Generators.Account do
  use Ash.Resource,
    otp_app: :AshPhoenixStarter,
    domain: AshPhoenixStarter.Accounts,
    data_layer: :not_persisted

  actions do
    action :generate_user, {:array, :struct} do
      argument :count, :integer, allow_nil?: false, default: 1

      constraints items: [instance_of: AshPhoenixStarter.Accounts.User]

      run fn input, _ctx ->
        users =
          AshPhoenixStarter.Generators.User.user()
          |> Ash.Generator.generate_many(
            input.arguments.count,
            authorize?: false
          )

        {:ok, users}
      end
    end
  end
end
