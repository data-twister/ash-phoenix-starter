defmodule AshPhoenixStarterWeb.Files.FileManagerLive do
  use AshPhoenixStarterWeb, :live_view

  require Ash.Query
  alias AshPhoenixStarter.Core.FileAsset

  on_mount {AshPhoenixStarterWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    org_id = resolve_user_org_uuid(socket.assigns.current_user)

    socket =
      socket
      |> assign(:organization_id, org_id)
      |> assign(:uploading?, false)
      |> assign(:upload_progress, 0)
      |> assign(:upload_filename, nil)
      |> assign(:upload_error, nil)
      |> stream(:assets, list_assets(org_id))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6 space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold">Files & Assets</h1>
          <p class="text-sm opacity-70">
            Resumable chunked uploads routed to your organization's active storage backend.
          </p>
        </div>
      </div>

      <%!-- Tus Uploader Dropzone / Input --%>
      <div
        id="tus-uploader-container"
        phx-hook="TusUploader"
        data-endpoint="/files"
        data-chunk-size={5 * 1024 * 1024}
        class="border-2 border-dashed border-base-300 rounded-xl p-8 text-center space-y-4 bg-base-100"
      >
        <input
          id="tus-file-input"
          type="file"
          class="file-input file-input-bordered w-full max-w-md"
          disabled={@uploading?}
        />

        <%= if @uploading? do %>
          <div class="max-w-md mx-auto space-y-2">
            <div class="flex justify-between text-xs font-medium">
              <span class="truncate">{@upload_filename}</span>
              <span>{@upload_progress}%</span>
            </div>
            <progress
              class="progress progress-primary w-full"
              value={@upload_progress}
              max="100"
            >
            </progress>
          </div>
        <% end %>

        <%= if @upload_error do %>
          <div class="alert alert-error max-w-md mx-auto text-sm">
            <span>{@upload_error}</span>
          </div>
        <% end %>
      </div>

      <%!-- Uploaded FileAssets Table --%>
      <div class="overflow-x-auto bg-base-100 rounded-xl border border-base-300">
        <table class="table w-full">
          <thead>
            <tr>
              <th>Filename</th>
              <th>Type</th>
              <th>Size</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody id="file-assets-list" phx-update="stream">
            <tr id="file-assets-empty" class="hidden only:table-row">
              <td colspan="4" class="text-center py-8 opacity-60">
                No files uploaded yet.
              </td>
            </tr>
            <tr :for={{dom_id, asset} <- @streams.assets} id={dom_id}>
              <td class="font-medium">
                <a href={asset.file_url} target="_blank" rel="noopener" class="link link-primary">
                  {asset.filename}
                </a>
              </td>
              <td class="text-xs opacity-75">{asset.content_type || "—"}</td>
              <td class="text-xs opacity-75">{format_bytes(asset.file_size)}</td>
              <td class="text-right">
                <button
                  type="button"
                  phx-click="delete_asset"
                  phx-value-id={asset.id}
                  data-confirm="Delete this file from storage?"
                  class="btn btn-xs btn-error btn-outline"
                >
                  Delete
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # ============================================================================
  # LIVEVIEW EVENTS (Triggered by TusUploader JS Hook & Delete Button)
  # ============================================================================

  @impl true
  def handle_event("upload_started", %{"filename" => filename}, socket) do
    {:noreply,
     socket
     |> assign(:uploading?, true)
     |> assign(:upload_filename, filename)
     |> assign(:upload_progress, 0)
     |> assign(:upload_error, nil)}
  end

  @impl true
  def handle_event("upload_progress", %{"progress" => progress}, socket) do
    {:noreply, assign(socket, :upload_progress, progress)}
  end

  @impl true
  def handle_event("upload_complete", _params, socket) do
    # Refresh the stream from DB so the newly created FileAsset appears immediately
    assets = list_assets(socket.assigns.organization_id)

    {:noreply,
     socket
     |> assign(:uploading?, false)
     |> assign(:upload_progress, 100)
     |> stream(:assets, assets, reset: true)
     |> put_flash(:info, "File uploaded successfully.")}
  end

  @impl true
  def handle_event("upload_error", %{"message" => message}, socket) do
    {:noreply,
     socket
     |> assign(:uploading?, false)
     |> assign(:upload_error, message)}
  end

  @impl true
  def handle_event("delete_asset", %{"id" => id}, socket) do
    case Ash.get(FileAsset, id) do
      {:ok, asset} ->
        case FileAsset.destroy(asset) do
          :ok ->
            {:noreply,
             socket
             |> stream_delete(:assets, asset)
             |> put_flash(:info, "File deleted.")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to delete file.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "File not found.")}
    end
  end

  # ============================================================================
  # HELPERS
  # ============================================================================

  defp list_assets(nil) do
    FileAsset
    |> Ash.Query.filter(is_nil(organization_id))
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!()
  end

  defp list_assets(org_id) do
    FileAsset
    |> Ash.Query.filter(organization_id == ^org_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!()
  end

  defp resolve_user_org_uuid(%{organization: %{id: org_id}}) when is_binary(org_id), do: org_id

  defp resolve_user_org_uuid(%{current_organization: domain} = user) when is_binary(domain) do
    case Ash.load(user, :organization, actor: user) do
      {:ok, %{organization: %{id: org_id}}} -> org_id
      _ -> nil
    end
  end

  defp resolve_user_org_uuid(_), do: nil

  defp format_bytes(nil), do: "—"
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 2)} MB"
end
