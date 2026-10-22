# lib/AshPhoenixStarter/accounts/user_notification.ex
defmodule AshPhoenixStarter.Accounts.UserNotification do
  use Ash.Resource,
    domain: AshPhoenixStarter.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban]

  postgres do
    table "user_notifications"
    repo AshPhoenixStarter.Repo
  end

  oban do
    triggers do
      list_tenants fn -> AshPhoenixStarter.Repo.all_tenants() end

      trigger :send do
        debug? true
        queue :default
        action :send
        
        where expr(processed == false)
        scheduler_cron "* * * * *" 

        trigger_once? true
        worker_read_action :unprocessed

        worker_module_name AshPhoenixStarter.Accounts.UserNotification.AshOban.Worker.Send
        scheduler_module_name AshPhoenixStarter.Accounts.UserNotification.AshOban.Scheduler.Send
      end
    end
  end

  actions do
    default_accept [:sender_user_id, :recipient_user_id, :subject, :body, :read_at, :status, :processed]
    defaults [:read, :create, :update, :destroy]

    update :send do
      description "Send a new user notification to the user"
      change AshPhoenixStarter.Accounts.UserNotification.Changes.DeliverEmail
    end

    read :unprocessed do
      description "Read unprocessed notifications"
      filter expr(processed == false)
      prepare build(limit: 100, load: :recipient)
    end
  end

  preparations do
    prepare AshPhoenixStarter.Preparations.SetTenant
  end

  changes do
    change AshPhoenixStarter.Changes.SetTenant
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :sender_user_id, :uuid do
      description "The user who sent the notification"
      allow_nil? true
    end

    attribute :recipient_user_id, :uuid do
      description "The user who received the notification"
      allow_nil? false
    end

    attribute :subject, :string do
      description "The subject of the notification"
      allow_nil? false
    end

    attribute :body, :string do
      description "The body of the notification"
      allow_nil? false
    end

    attribute :read_at, :datetime do
      description "The time a notification has been read"
      default nil
      allow_nil? true
    end

    attribute :status, :atom do
      description "The status of the notification"
      default :unread
      allow_nil? false
      constraints one_of: [:unread, :read, :archived]
    end

    attribute :processed, :boolean do
      description "Whether the notification has been processed"
      default false
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :sender, AshPhoenixStarter.Accounts.User do
      description "The user who sent the notification"
      source_attribute :sender_user_id 
    end

    belongs_to :recipient, AshPhoenixStarter.Accounts.User do
      description "The user who received the notification"
      source_attribute :recipient_user_id
    end
  end
end
