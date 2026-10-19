# SPDX-FileCopyrightText: 2023 ash_double_entry contributors <https://github.com/ash-project/ash_double_entry/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenixStarter.Ledgers.Description do
  @moduledoc false
  use Ash.Resource,
    domain: Elixir.AshPhoenixStarter.Ledgers,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshDoubleEntry.Description]

  postgres do
    table "ledger_entries"
    repo AshPhoenixStarter.Repo
  end

  description do
    transfer_resource AshPhoenixStarter.Ledgers.Transfer
    account_resource AshPhoenixStarter.Ledgers.Account
  end

  code_interface do
    define :read, action: :read
    define :list, action: :read
  end

  actions do
    defaults [:read, :destroy]
  end
end