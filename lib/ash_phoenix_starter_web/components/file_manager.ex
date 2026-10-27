defmodule AshPhoenixStarterWeb.Components.FileManagerComponent do
  use AshPhoenixStarterWeb, :live_component
  alias AshPhoenixStarter.Uploads.ImageUploader
  alias AshPhoenixStarter.Core.FileAsset

  import Ash.Query

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:selected_file, nil)
     |> assign(:active_tab, :browse)
     |> assign(:offset, 0)
     |> assign(:file_library, [])
     |> assign(:has_more, false)
     |> allow_upload(:file,
       accept: ~w(.jpg .jpeg .png .webp .pdf .doc .docx .xls .xlsx .txt .zip),
       max_entries: 5,
       max_file_size: 25_000_000
     )}
  end

  @impl true
  def update(assigns, socket) do
    team_id = assigns.current_user.team.id

    socket =
      if socket.assigns[:team_id] != team_id do
        existing_files =
          FileAsset
          |> Ash.Query.for_read(:read)
          |> filter(team_id == ^team_id)
          |> sort(inserted_at: :desc)
          |> limit(100)
          |> Ash.read!()

        socket
        |> assign(:team_id, team_id)
        |> assign(:file_library, existing_files)
        |> assign(:has_more, length(existing_files) == 100)
      else
        socket
      end

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_atom(tab))}
  end

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("load_more", _, socket) do
    if not socket.assigns.has_more do
      {:noreply, socket}
    else
      team_id = socket.assigns.team_id
      new_offset = socket.assigns.offset + 100

      more_files =
        FileAsset
        |> Ash.Query.for_read(:read)
        |> filter(team_id == ^team_id)
        |> sort(inserted_at: :desc)
        |> offset(new_offset)
        |> limit(100)
        |> Ash.read!()

      has_more = length(more_files) == 100
      updated_library = socket.assigns.file_library ++ more_files

      {:noreply,
       socket
       |> assign(:file_library, updated_library)
       |> assign(:offset, new_offset)
       |> assign(:has_more, has_more)}
    end
  end

  @impl true
  def handle_event("save_uploads", _params, socket) do
    team_id = socket.assigns.team_id

    results =
      consume_uploaded_entries(socket, :file, fn %{path: path}, entry ->
        scope = %{team_id: team_id}
        file_input = %{filename: entry.client_name, path: path}

        case ImageUploader.store({file_input, scope}) do
          {:ok, filename} ->
            url = ImageUploader.url({filename, scope}, :original)

            result =
              FileAsset
              |> Ash.Changeset.for_create(:create, %{
                filename: entry.client_name,
                file_url: url,
                file_size: entry.client_size,
                content_type: entry.client_type,
                team_id: team_id
              })
              |> Ash.create!()

            {:ok, result}

          {:error, reason} ->
            {:error, reason}
        end
      end)

    {successes, errors} =
      Enum.split_with(results, fn
        {:ok, _} -> true
        _ -> false
      end)

    uploaded_records = Enum.map(successes, fn {:ok, record} -> record end)
    updated_library = uploaded_records ++ socket.assigns.file_library

    socket =
      socket
      |> assign(:file_library, updated_library)
      |> assign(:active_tab, :browse)

    socket =
      if length(errors) > 0 do
        put_flash(socket, :error, "Some files failed to upload. Please check format/size.")
      else
        put_flash(socket, :info, "Successfully uploaded #{length(uploaded_records)} file(s)!")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_library_file", %{"id" => file_id}, socket) do
    file = Enum.find(socket.assigns.file_library, &(&1.id == file_id))
    {:noreply, assign(socket, :selected_file, file)}
  end

  @impl true
  def handle_event("confirm_selection", _, socket) do
    # Optional: Send notification back to parent LiveView if needed
    # send(self(), {:file_selected, socket.assigns.selected_file})
    {:noreply, put_flash(socket, :info, "File attached successfully!")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto p-6 bg-base-100 rounded-2xl shadow-sm border border-base-200 grid grid-cols-1 md:grid-cols-3 gap-6">
      <!-- Main Content Section (Browse / Upload Tabs) -->
      <div class="md:col-span-2 space-y-6">
        <div class="flex justify-between items-center">
          <div>
            <h2 class="text-xl font-semibold tracking-tight text-base-content">
              File & Asset Manager
            </h2>

            <p class="text-sm text-base-content/60 mt-1">
              Select files from your library or upload new documents and media.
            </p>
          </div>

          <div class="flex bg-base-200 p-1 rounded-xl border border-base-300">
            <button
              type="button"
              phx-click="switch_tab"
              phx-value-tab="browse"
              phx-target={@myself}
              class={"px-4 py-1.5 text-sm font-medium rounded-lg transition-all " <> if(@active_tab == :browse, do: "bg-base-100 text-base-content shadow-sm", else: "text-base-content/70 hover:text-base-content")}
            >
              Browse Library ({length(@file_library)})
            </button>
            <button
              type="button"
              phx-click="switch_tab"
              phx-value-tab="upload"
              phx-target={@myself}
              class={"px-4 py-1.5 text-sm font-medium rounded-lg transition-all " <> if(@active_tab == :upload, do: "bg-base-100 text-base-content shadow-sm", else: "text-base-content/70 hover:text-base-content")}
            >
              Upload New
            </button>
          </div>
        </div>

        <%= if @active_tab == :browse do %>
          <div>
            <%= if Enum.empty?(@file_library) do %>
              <div class="text-center py-12 border-2 border-dashed border-base-300 rounded-xl">
                <p class="text-base-content/60 text-sm">
                  No files uploaded yet. Switch to "Upload New" to add files.
                </p>
              </div>
            <% else %>
              <div
                id="file-library-scroll"
                phx-update="replace"
                phx-viewport-bottom="load_more"
                phx-target={@myself}
                class="grid grid-cols-2 sm:grid-cols-3 gap-4 max-h-[420px] overflow-y-auto p-2"
              >
                <%= for file <- @file_library do %>
                  <div
                    phx-click="select_library_file"
                    phx-value-id={file.id}
                    phx-target={@myself}
                    class={"group relative bg-base-200/50 rounded-xl border-2 overflow-hidden cursor-pointer transition-all flex flex-col " <>
                      if(@selected_file && @selected_file.id == file.id, do: "border-primary ring-2 ring-primary/20", else: "border-base-300 hover:border-base-content/30")}
                  >
                    <div class="h-28 bg-base-300 flex items-center justify-center overflow-hidden">
                      <%= if is_image?(file.content_type) do %>
                        <img
                          src={file.file_url}
                          class="object-cover w-full h-full group-hover:scale-105 transition-transform duration-200"
                        />
                      <% else %>
                        <div class="flex flex-col items-center justify-center text-base-content/50">
                          <svg
                            class="w-10 h-10 mb-1"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="1.5"
                              d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"
                            />
                          </svg>
                          <span class="text-[10px] font-bold uppercase tracking-wider">
                            {file_extension(file.filename)}
                          </span>
                        </div>
                      <% end %>
                    </div>

                    <div class="p-2.5 flex-1 flex flex-col justify-between">
                      <p class="text-xs font-medium text-base-content truncate">{file.filename}</p>

                      <p class="text-[10px] text-base-content/50 mt-0.5">
                        {format_size(file.file_size)}
                      </p>
                    </div>

                    <%= if @selected_file && @selected_file.id == file.id do %>
                      <div class="absolute top-2 right-2 bg-primary text-primary-content rounded-full p-1 shadow-md">
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2.5"
                            d="M5 13l4 4L19 7"
                          />
                        </svg>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>

        <%= if @active_tab == :upload do %>
          <form id="upload-form" phx-submit="save_uploads" phx-change="validate" phx-target={@myself}>
            <div class="border-2 border-dashed border-base-300 rounded-xl p-8 text-center hover:border-base-content/40 transition-all bg-base-200/30">
              <.live_file_input upload={@uploads.file} class="sr-only" />
              <label
                for={@uploads.file.ref}
                class="cursor-pointer flex flex-col items-center justify-center"
              >
                <svg
                  class="w-10 h-10 text-base-content/40 mb-3"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="1.5"
                    d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                  />
                </svg>
                <span class="text-sm font-medium text-base-content">
                  Click to upload or drag & drop files
                </span>
                <span class="text-xs text-base-content/50 mt-1">Images, PDFs, Docs up to 25MB</span>
              </label>
            </div>

            <div class="space-y-3 mt-4">
              <%= for entry <- @uploads.file.entries do %>
                <div class="flex items-center gap-4 p-3 bg-base-200/50 rounded-xl border border-base-300">
                  <div class="w-12 h-12 bg-base-300 rounded-lg overflow-hidden flex-shrink-0 flex items-center justify-center">
                    <%= if String.starts_with?(entry.client_type || "", "image/") do %>
                      <.live_img_preview entry={entry} class="object-cover w-full h-full" />
                    <% else %>
                      <svg
                        class="w-6 h-6 text-base-content/50"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="1.5"
                          d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"
                        />
                      </svg>
                    <% end %>
                  </div>

                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-base-content truncate">{entry.client_name}</p>

                    <div class="w-full bg-base-300 rounded-full h-1.5 mt-1 overflow-hidden">
                      <div
                        class="bg-primary h-1.5 rounded-full transition-all duration-150"
                        style={"width: #{entry.progress}%"}
                      >
                      </div>
                    </div>
                  </div>

                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    phx-target={@myself}
                    class="text-base-content/40 hover:text-error"
                  >
                    ✕
                  </button>
                </div>
              <% end %>
            </div>

            <div class="mt-6 flex justify-end">
              <.button type="submit" disabled={Enum.empty?(@uploads.file.entries)}>
                Upload & Save to Library
              </.button>
            </div>
          </form>
        <% end %>
      </div>
      <!-- Right Sidebar: Selected File Inspection Panel -->
      <div class="bg-base-200/40 p-5 rounded-xl border border-base-300 flex flex-col justify-between">
        <div>
          <h3 class="text-sm font-semibold text-base-content mb-3 uppercase tracking-wider">
            Selected Preview
          </h3>

          <%= if @selected_file do %>
            <div class="space-y-4">
              <div class="w-full h-40 bg-base-300 rounded-lg overflow-hidden flex items-center justify-center border border-base-300 shadow-inner">
                <%= if is_image?(@selected_file.content_type) do %>
                  <img src={@selected_file.file_url} class="object-contain w-full h-full" />
                <% else %>
                  <div class="flex flex-col items-center justify-center text-base-content/60 p-4 text-center">
                    <svg
                      class="w-12 h-12 mb-2 text-primary"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="1.5"
                        d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"
                      />
                    </svg>
                     <span class="text-xs font-semibold">{@selected_file.filename}</span>
                    <span class="text-[10px] text-base-content/50 uppercase mt-1">
                      {@selected_file.content_type ||
                        "Document"}
                    </span>
                  </div>
                <% end %>
              </div>

              <div class="space-y-1.5 text-xs">
                <p class="text-base-content font-medium truncate" title={@selected_file.filename}>
                  <span class="text-base-content/50">Name:</span> {@selected_file.filename}
                </p>

                <p class="text-base-content">
                  <span class="text-base-content/50">Size:</span> {format_size(
                    @selected_file.file_size
                  )}
                </p>

                <p class="text-base-content truncate">
                  <span class="text-base-content/50">URL:</span>
                  <a href={@selected_file.file_url} target="_blank" class="text-primary underline">
                    Open File
                  </a>
                </p>
              </div>
            </div>
          <% else %>
            <div class="h-40 border-2 border-dashed border-base-300 rounded-lg flex items-center justify-center text-center p-4">
              <p class="text-xs text-base-content/50">
                Click any file from the browse view to preview and attach it.
              </p>
            </div>
          <% end %>
        </div>

        <div class="mt-6 pt-4 border-t border-base-300">
          <.button
            type="button"
            class="w-full"
            phx-click="confirm_selection"
            phx-target={@myself}
            disabled={is_nil(@selected_file)}
          >
            Attach File
          </.button>
        </div>
      </div>
    </div>
    """
  end

  defp is_image?(nil), do: false
  defp is_image?(content_type), do: String.starts_with?(content_type, "image/")

  defp file_extension(filename) do
    filename |> Path.extname() |> String.trim_leading(".")
  end

  defp format_size(nil), do: ""
  defp format_size(bytes) when bytes < 1024_000, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_size(bytes), do: "#{Float.round(bytes / 1024_000, 1)} MB"
end
