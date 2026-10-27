defmodule AshPhoenixStarter.Accounts.User.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, AshPhoenixStarter.Accounts.Organization do
      description "Current organization object"
      source_attribute :current_organization
      destination_attribute :domain
    end

    many_to_many :organizations, AshPhoenixStarter.Accounts.Organization do
      through AshPhoenixStarter.Accounts.UserOrganization
      source_attribute_on_join_resource :user_id
      destination_attribute_on_join_resource :organization_id
    end

    many_to_many :groups, AshPhoenixStarter.Accounts.Group do
      through AshPhoenixStarter.Accounts.UserGroup
      source_attribute_on_join_resource :user_id
      destination_attribute_on_join_resource :group_id
    end

    has_many :impersonations, AshPhoenixStarter.Accounts.UserImpersonation do
      destination_attribute :impersonated_user_id
      description "Active impersonation for this user"
    end
  end
end
