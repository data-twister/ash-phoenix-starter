defmodule AshPhoenixStarter.Settings.Payment.Gateway.Setting do
  use Ash.Resource,
    domain: AshPhoenixStarter.Settings,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "payment_gateway_settings"
    repo AshPhoenixStarter.Repo
  end

  code_interface do
    define :read, action: :read
    define :list, action: :read
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :gateway_type,
        :api_key,
        :api_secret,
        :webhook_secret,
        :test_mode,
        :active,
        :additional_settings
      ]
    end

    update :update do
      accept [
        :api_key,
        :api_secret,
        :webhook_secret,
        :test_mode,
        :active,
        :additional_settings
      ]
    end
  end

  preparations do
    prepare AshPhoenixStarter.Preparations.SetTenant
  end

  changes do
    change AshPhoenixStarter.Accounts.Changes.SetTenant
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :gateway_type, :atom do
      constraints one_of: [
                    :stripe,
                    :quickbooks,
                    :zelle,
                    :paypal,
                    :venmo,
                    :plaid,
                    :mercury
                  ]

      allow_nil? false
    end

    attribute :api_key, :string, allow_nil?: false, sensitive?: true
    attribute :api_secret, :string, allow_nil?: false, sensitive?: true
    attribute :webhook_secret, :string, sensitive?: true

    attribute :test_mode, :boolean, default: true, allow_nil?: false
    attribute :active, :boolean, default: true, allow_nil?: false

    # Stores gateway-specific metadata (e.g., realm_id for QuickBooks, redirect_uris, webhook URLs)
    attribute :additional_settings, :map, default: %{}

    timestamps()
  end
end
