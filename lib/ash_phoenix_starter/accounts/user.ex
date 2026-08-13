defmodule AshPhoenixStarter.Accounts.User do
  use Ash.Resource,
    otp_app: :AshPhoenixStarter,
    domain: AshPhoenixStarter.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication, AshOban],
    fragments: [
      AshPhoenixStarter.Accounts.User.Actions,
      AshPhoenixStarter.Accounts.User.Attributes,
      AshPhoenixStarter.Accounts.User.Relationships
    ]

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end

      confirmation :confirm_new_user do
        monitor_fields [:email]
        confirm_on_create? true
        confirm_on_update? false
        require_interaction? true
        confirmed_at_field :confirmed_at
        auto_confirm_actions [:sign_in_with_magic_link, :reset_password_with_token]
        sender AshPhoenixStarter.Accounts.User.Senders.SendNewUserConfirmationEmail
      end
    end

    tokens do
      enabled? true
      token_resource AshPhoenixStarter.Accounts.Token
      signing_secret AshPhoenixStarter.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      password :password do
        identity_field :email
        hash_provider AshAuthentication.BcryptProvider

        resettable do
          sender AshPhoenixStarter.Accounts.User.Senders.SendPasswordResetEmail
          # these configurations will be the default in a future release
          password_reset_action_name :reset_password_with_token
          request_password_reset_action_name :request_password_reset_token
        end
      end

      magic_link do
        identity_field :email
        registration_enabled? true
        require_interaction? true

        sender AshPhoenixStarter.Accounts.User.Senders.SendMagicLinkEmail
      end
    end
  end

  postgres do
    table "users"
    repo AshPhoenixStarter.Repo
  end

  oban do
    triggers do
      trigger :reset_empty_admin_password do
        action :admin_set_default_password
        worker_read_action :list_empty_password_admins
        scheduler_cron false
        queue :system
        actor_persister AshPhoenixStarter.Accounts.ObanActorPersister
        worker_module_name AshPhoenixStarter.Accounts.User.Empty.Password.Reset.AshOban.Worker

        scheduler_module_name AshPhoenixStarter.Accounts.User.Empty.Password.Reset.AshOban.Scheduler.Process
      end
    end
  end

  policies do
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  preparations do
    prepare build(load: :team)
  end

  changes do
    change AshPhoenixStarter.Accounts.User.Changes.CreatePersonTeam
  end
end
