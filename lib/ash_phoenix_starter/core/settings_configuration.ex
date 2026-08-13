defmodule AshPhoenixStarter.Settings.Configuration do
  @moduledoc """
  An Ash Framework resource representing a single key-value configuration entry 
  persisted in the PostgreSQL database.

  `Configuration` acts as the persistent storage layer for `AshPhoenixStarter.SettingsManager`. 
  It stores configuration settings as string-serialized values alongside a explicit 
  `type` metadata field (`string`, `integer`, `boolean`, `float`, or `atom`), allowing 
  the application to safely coerce rows back into native Elixir data types on retrieval.

  ## Database Schema (`app_settings`)
  * `key` - A unique string identifier for the setting (e.g., `"image_mode"`).
  * `value` - The raw string representation of the configuration value.
  * `type` - The primitive type descriptor used for casting (`string`, `integer`, `boolean`, `float`, `atom`).
  """

  use Ash.Resource,
    domain: AshPhoenixStarter.Core,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "app_settings"
    repo AshPhoenixStarter.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      description "Creates a new configuration setting with a key, value, and type."
      accept [:key, :value, :type]
      primary? true
    end

    update :update do
      description "Updates the value and type metadata of an existing configuration setting."
      accept [:value, :type]
    end
  end

  validations do
    validate one_of(:type, ["string", "integer", "boolean", "atom", "float"]),
      message: "must be a supported primitive type descriptor"
  end

  attributes do
    uuid_primary_key :id

    attribute :key, :string do
      description "The unique lookup key for the setting."
      allow_nil? false
      public? true
    end

    attribute :value, :string do
      description "The serialized string value of the configuration option."
      allow_nil? false
      public? true
    end

    attribute :type, :string do
      description "The primitive type indicator used to cast the value back to its native Elixir form."
      allow_nil? false
      default "string"
      public? true
    end

    timestamps()
  end

  identities do
    identity :unique_key, [:key], message: "configuration keys must be unique"
  end
end
