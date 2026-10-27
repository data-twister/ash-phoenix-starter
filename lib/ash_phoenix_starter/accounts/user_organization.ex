defmodule AshPhoenixStarter.Accounts.UserOrganization do
  use Ash.Resource,
    domain: AshPhoenixStarter.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "user_organizations"
    repo AshPhoenixStarter.Repo
  end

  resource do
    # We don't need primary key for this resource
    require_primary_key? false
  end

  actions do
    default_accept [:user_id, :organization_id]
    defaults [:create, :read, :update, :destroy]
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :user, AshPhoenixStarter.Accounts.User do
      source_attribute :user_id
    end

    belongs_to :organization, AshPhoenixStarter.Accounts.Organization do
      source_attribute :organization_id
    end
  end

  identities do
    identity :unique_user_organization, [:user_id, :organization_id]
  end
end
