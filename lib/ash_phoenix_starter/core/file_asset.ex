defmodule AshPhoenixStarter.Core.FileAsset do
  use Ash.Resource,
    domain: AshPhoenixStarter.Core,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "file_assets"
    repo AshPhoenixStarter.Repo
  end

  code_interface do
    define :read, action: :read
    define :list, action: :read
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:filename, :file_url, :file_size, :content_type, :organization_id, :type]
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :filename, :string, allow_nil?: false
    attribute :file_url, :string, allow_nil?: false
    attribute :file_size, :integer
    attribute :content_type, :string
    attribute :organization_id, :uuid, allow_nil?: true

    attribute :type, :atom do
      constraints one_of: [:general]
      default :general
      allow_nil? false
    end

    timestamps()
  end
end
