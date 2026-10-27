defmodule AshPhoenixStarter.Ledger do
  use Ash.Domain,
    otp_app: :ash_phoenix_starter

  resources do
    resource AshPhoenixStarter.Ledger.Account
    resource AshPhoenixStarter.Ledger.Balance
    resource AshPhoenixStarter.Ledger.Transfer
    resource AshPhoenixStarter.Ledger.Description
  end
end
