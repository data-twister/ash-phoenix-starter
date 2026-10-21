# lib/AshPhoenixStarter/accounts/invitation.ex
defmodule AshPhoenixStarter.Accounts.Invitation do
  use Ash.Resource,
    domain: AshPhoenixStarter.Accounts,
    data_layer: AshPostgres.DataLayer,
    notifiers: Ash.Notifier.PubSub

  postgres do
    table "invitations"
    repo AshPhoenixStarter.Repo
  end

  code_interface do
    define :accept, action: :accept
    define :get_by_token, args: [:token], action: :by_token
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      description """
      This action assumes that inserting new data == inviting a new users. It will then:
      1. Generate a unique token for the invitation and add it to the changeset
      2. Set new invitation attributes such as:  expires_at, team, etc.
      3. Sends an invitation to the newly invited user via email
      """

      accept [:email, :group_id]
      change AshPhoenixStarter.Accounts.Invitation.Changes.SetInvitationAttributes
      change AshPhoenixStarter.Accounts.Invitation.Changes.SendInvitationEmail
    end

    read :by_token do
      description "Get one invitation by its token"
      argument :token, :string
      filter expr(token == ^arg(:token))
      get? true
    end

    update :accept do
      description """
      When an invitee accepts invitation, this action will be called:
      1. Add invitee to the team based on the invitation data
      2. Add invitee to the permission group based on the invitation data
      3. Send invitee a welcome email to the newly added user to the team
      """

      accept []

      validate AshPhoenixStarter.Accounts.Invitation.Validations.EnsurePendingStatus

      change atomic_update(:status, :accepted)
      change AshPhoenixStarter.Accounts.Invitation.Changes.AddUserToTeam
      change AshPhoenixStarter.Accounts.Invitation.Changes.SendWelcomeEmail
    end

    update :decline do
      description """
      When an invitee declines invitation, this action will be called:
      1. Changes the status to the declined.
      2. Send a decline email.
      """

      accept []

      validate AshPhoenixStarter.Accounts.Invitation.Validations.EnsurePendingStatus

      change set_attribute(:status, :declined)
      change AshPhoenixStarter.Accounts.Invitation.Changes.SendDeclinedEmail
    end
  end

  # Confirm how Ash will wor
  pub_sub do
    module AshPhoenixStarterWeb.Endpoint
    prefix "invitations"
    publish_all :update, [[:id, :team, nil]]
    publish_all :create, [[:id, :team, nil]]
    publish_all :destroy, [[:id, :team, nil]]
  end

  preparations do
    prepare AshPhoenixStarter.Preparations.SetTenant
    prepare AshPhoenixStarter.Accounts.Invitation.Preparations.ForCurrentTeam
  end

  changes do
    change AshPhoenixStarter.Changes.SetTenant
  end

  multitenancy do
    strategy :context
    global? true
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string do
      allow_nil? false
      constraints match: ~r/^[^\s]+@[^\s]+\.[^\s]+$/
      description "Email address of the user to invite"
    end

    attribute :status, :atom do
      default :pending
      allow_nil? false
      constraints one_of: [:pending, :accepted, :declined]
      description "The status of the invitation sent to the user"
    end

    attribute :token, :string do
      allow_nil? false
      description "The token in the URL to identify this invitation"
    end

    attribute :team, :string do
      allow_nil? false
      description "The team the user will be added to after accepting invitation"
    end

    attribute :expires_at, :utc_datetime do
      allow_nil? false
      description "The time this invitation will expire. Default 30 days"
    end

    timestamps()
  end

  relationships do
    belongs_to :group, AshPhoenixStarter.Accounts.Group do
      allow_nil? false
      source_attribute :group_id
      description "User permission group the invitee will be added to"
    end

    belongs_to :inviter, AshPhoenixStarter.Accounts.User do
      allow_nil? false
      source_attribute :inviter_user_id
      description "The user who sent this invitation to the new joiner"
    end

    belongs_to :invitee, AshPhoenixStarter.Accounts.User do
      allow_nil? true
      source_attribute :invitee_user_id
      description "The invited user. This will not be nil if the user already exists in the app"
    end
  end
end