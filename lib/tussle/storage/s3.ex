defmodule Tussle.Storage.S3 do
  @moduledoc """
  Multi-tenant Amazon S3 (and S3-compatible) storage backend for the [Tussle](https://hex.pm) server.

  ## Telemetry Events

  * `[:tussle, :storage, :s3, :request, :start]`
  * `[:tussle, :storage, :s3, :request, :stop]`
  * `[:tussle, :storage, :s3, :request, :exception]`

  Metadata includes `:operation`, `:bucket`, `:key`, and `:result` (`:ok` or `:error` on `:stop`).
  """

  alias ExAws.S3
  alias AshPhoenixStarter.Uploads.TenantConfig

  @type file :: %{
          required(:uid) => String.t(),
          required(:offset) => non_neg_integer(),
          required(:size) => non_neg_integer(),
          optional(:upload_id) => String.t(),
          optional(:parts) => [{pos_integer(), String.t()}],
          optional(:path) => String.t()
        }

  defmodule Client do
    @moduledoc false
    @callback request(ExAws.Operation.t(), keyword()) :: {:ok, term()} | {:error, term()}
  end

  defmodule DefaultClient do
    @moduledoc false
    @behaviour Client

    @impl Client
    def request(operation, opts), do: ExAws.request(operation, opts)
  end

  defmodule Config do
    @moduledoc false
    @default_host "amazonaws.com"
    @default_min_part_size 5 * 1024 * 1024

    @enforce_keys [:bucket]
    defstruct [
      :bucket,
      :region,
      :scheme,
      :port,
      :acl,
      :access_key_id,
      :secret_access_key,
      virtual_host: false,
      prefix: "",
      host: @default_host,
      min_part_size: @default_min_part_size,
      client: Tussle.Storage.S3.DefaultClient
    ]

    def new(%{organization_id: org_id} = raw_config) when not is_nil(org_id) do
      aws_cfg = TenantConfig.ex_aws_config(org_id)
      s3_cfg = Keyword.get(aws_cfg, :s3, [])

      %__MODULE__{
        bucket: Map.get(raw_config, :s3_bucket) || TenantConfig.bucket(org_id),
        prefix: raw_config |> Map.get(:s3_prefix, "") |> String.trim("/"),
        host: Map.get(raw_config, :s3_host) || Keyword.get(s3_cfg, :host, @default_host),
        region: Map.get(raw_config, :s3_region) || Keyword.get(aws_cfg, :region),
        scheme: Map.get(raw_config, :s3_scheme) || Keyword.get(s3_cfg, :scheme),
        port: Map.get(raw_config, :s3_port) || Keyword.get(s3_cfg, :port),
        virtual_host:
          Map.get(raw_config, :s3_virtual_host, Keyword.get(s3_cfg, :virtual_host, false)),
        access_key_id: Keyword.get(aws_cfg, :access_key_id),
        secret_access_key: Keyword.get(aws_cfg, :secret_access_key),
        acl: Map.get(raw_config, :s3_acl),
        min_part_size: Map.get(raw_config, :s3_min_part_size, @default_min_part_size),
        client: Map.get(raw_config, :s3_client, Tussle.Storage.S3.DefaultClient)
      }
    end

    def new(raw_config) when is_map(raw_config) do
      %__MODULE__{
        bucket: Map.fetch!(raw_config, :s3_bucket),
        prefix: raw_config |> Map.get(:s3_prefix, "") |> String.trim("/"),
        host: Map.get(raw_config, :s3_host, @default_host),
        region: Map.get(raw_config, :s3_region),
        scheme: Map.get(raw_config, :s3_scheme),
        port: Map.get(raw_config, :s3_port),
        virtual_host: Map.get(raw_config, :s3_virtual_host, false),
        access_key_id: Map.get(raw_config, :s3_access_key_id),
        secret_access_key: Map.get(raw_config, :s3_secret_access_key),
        acl: Map.get(raw_config, :s3_acl),
        min_part_size: Map.get(raw_config, :s3_min_part_size, @default_min_part_size),
        client: Map.get(raw_config, :s3_client, Tussle.Storage.S3.DefaultClient)
      }
    end

    def request_opts(%__MODULE__{} = cfg) do
      [
        host: cfg.host,
        region: cfg.region,
        scheme: cfg.scheme,
        port: cfg.port,
        virtual_host: cfg.virtual_host,
        access_key_id: cfg.access_key_id,
        secret_access_key: cfg.secret_access_key
      ]
      |> Enum.reject(fn {_key, val} -> is_nil(val) end)
    end

    def init_opts(%__MODULE__{acl: nil}), do: []
    def init_opts(%__MODULE__{acl: acl}), do: [acl: acl]

    def object_key(%__MODULE__{prefix: ""}, uid), do: uid
    def object_key(%__MODULE__{prefix: prefix}, uid), do: "#{prefix}/#{uid}"
  end

  @doc """
  Initiates a multipart upload in S3 and attaches `:upload_id`, `:parts`, and `:path`.
  """
  @spec create(file(), map()) :: {:ok, file()} | {:error, term()}
  def create(file, raw_config) do
    cfg = Config.new(raw_config)
    key = Config.object_key(cfg, file.uid)

    with {:ok, %{body: %{upload_id: upload_id}}} <-
           cfg.bucket
           |> S3.initiate_multipart_upload(key, Config.init_opts(cfg))
           |> execute(cfg, :create, key) do
      {:ok, Map.merge(file, %{upload_id: upload_id, parts: [], path: key})}
    end
  end

  @doc """
  Appends a binary chunk as the next part in an active multipart upload.
  Returns `:too_small` when the chunk is smaller than `s3_min_part_size` and is not the final chunk.
  """
  @spec append(file(), map(), binary()) :: {:ok, file()} | :too_small | {:error, term()}
  def append(file, raw_config, body) do
    cfg = Config.new(raw_config)

    if valid_chunk_size?(file, cfg, byte_size(body)) do
      upload_next_part(file, cfg, body)
    else
      :too_small
    end
  end

  @doc """
  Finalizes a multipart upload once all parts have been uploaded.
  """
  @spec complete_upload(file(), map()) :: {:ok, file()} | {:error, term()}
  def complete_upload(file, raw_config) do
    cfg = Config.new(raw_config)
    key = Config.object_key(cfg, file.uid)

    with {:ok, _response} <-
           cfg.bucket
           |> S3.complete_multipart_upload(key, file.upload_id, file.parts)
           |> execute(cfg, :complete, key) do
      {:ok, file}
    end
  end

  @doc """
  Aborts any active multipart upload and deletes the target object from S3.
  """
  @spec delete(file(), map()) :: :ok | {:error, term()}
  def delete(file, raw_config) do
    cfg = Config.new(raw_config)
    key = Config.object_key(cfg, file.uid)

    with :ok <- maybe_abort_upload(file, cfg, key),
         {:ok, _response} <- cfg.bucket |> S3.delete_object(key) |> execute(cfg, :delete, key) do
      :ok
    end
  end

  # --- Private Helpers ---

  defp upload_next_part(file, cfg, body) do
    key = Config.object_key(cfg, file.uid)
    part_number = length(file.parts) + 1

    with {:ok, %{headers: headers}} <-
           cfg.bucket
           |> S3.upload_part(key, file.upload_id, part_number, body)
           |> execute(cfg, :upload_part, key),
         {:ok, etag} <- fetch_etag(headers) do
      {:ok, %{file | parts: file.parts ++ [{part_number, etag}]}}
    end
  end

  defp maybe_abort_upload(%{upload_id: upload_id}, cfg, key) when is_binary(upload_id) do
    case cfg.bucket |> S3.abort_multipart_upload(key, upload_id) |> execute(cfg, :abort, key) do
      {:ok, _response} -> :ok
      {:error, {:http_error, 404, _}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_abort_upload(_file, _cfg, _key), do: :ok

  defp valid_chunk_size?(file, cfg, chunk_size) do
    final_chunk? = file.offset + chunk_size >= file.size
    chunk_size >= cfg.min_part_size or final_chunk?
  end

  defp fetch_etag(headers) do
    headers
    |> Enum.find_value(fn {k, v} -> if String.downcase(k) == "etag", do: v end)
    |> case do
      nil -> {:error, :missing_etag}
      etag -> {:ok, etag}
    end
  end

  defp execute(operation, %Config{client: client} = cfg, op_name, key) do
    metadata = %{operation: op_name, bucket: cfg.bucket, key: key}

    :telemetry.span([:tussle, :storage, :s3, :request], metadata, fn ->
      result = client.request(operation, Config.request_opts(cfg))
      status = if match?({:ok, _}, result), do: :ok, else: :error
      {result, Map.put(metadata, :result, status)}
    end)
  end
end
