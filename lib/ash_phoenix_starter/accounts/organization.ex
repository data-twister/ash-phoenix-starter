defmodule AshPhoenixStarter.Accounts.Organization do
  require Ash.Resource.Change.Builtins

  use Ash.Resource,
    domain: AshPhoenixStarter.Accounts,
    data_layer: AshPostgres.DataLayer

  @doc """
  Tell ash to use domain as the tenant database prefix when we are using
  postgresql as the database, otherwise use the ID
  """
  defimpl Ash.ToTenant do
    def to_tenant(resource, %{:domain => domain, :id => id}) do
      if Ash.Resource.Info.data_layer(resource) == AshPostgres.DataLayer &&
           Ash.Resource.Info.multitenancy_strategy(resource) == :context do
        domain
      else
        id
      end
    end
  end

  postgres do
    table "organizations"
    repo AshPhoenixStarter.Repo

    manage_tenant do
      template ["", :domain]
      create? true
      update? false
    end
  end

  actions do
    default_accept [:name, :domain, :description, :owner_user_id]
    defaults [:read]

    create :create do
      primary? true
      change AshPhoenixStarter.Accounts.Organization.Changes.AddUserOrganization
      change AshPhoenixStarter.Accounts.Organization.Changes.AddOrganizationOwner
      change AshPhoenixStarter.Accounts.Organization.Changes.SwitchActorOrganization
    end

    read :by_domain do
      get? true
      argument :domain, :string
      filter expr(domain == ^arg(:domain))
      description "Get organization details by its domain"
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      description "Organization or organisation name"
    end

    attribute :domain, :string do
      allow_nil? false
      public? true
      description "Domain name of the organization or organisation"
    end

    attribute :active, :boolean do
      allow_nil? false
      default true
      public? true
      description "Organization Active?"
    end

    attribute :description, :string, allow_nil?: true, public?: true

    timestamps()
  end

  relationships do
    belongs_to :owner, AshPhoenixStarter.Accounts.User do
      source_attribute :owner_user_id
    end

    many_to_many :users, AshPhoenixStarter.Accounts.User do
      through AshPhoenixStarter.Accounts.UserOrganization
      source_attribute_on_join_resource :organization_id
      destination_attribute_on_join_resource :user_id
    end
  end

  identities do
    identity :unique_domain, [:domain] do
      description "Identity to find a organization by its domain"
    end
  end
end
