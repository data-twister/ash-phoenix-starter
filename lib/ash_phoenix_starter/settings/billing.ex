defmodule AshPhoenixStarter.Settings.Billing do
  @moduledoc """
  The billing helper module this serves as an example of how to create an item in group permissions.
  """
  use Ash.Resource,
    otp_app: :AshPhoenixStarter,
    domain: AshPhoenixStarter.Settings,
    data_layer: Ash.DataLayer.Simple

  actions do
    action :manage, :boolean do
      description "Manage access to the billing portal, invoices, and subscription settings"
    end
  end
end
