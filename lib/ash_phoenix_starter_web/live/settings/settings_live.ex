defmodule AshPhoenixStarterWeb.Settings.SettingsLive do
  use AshPhoenixStarterWeb, :live_view

  alias AshPhoenixStarter.Settings.Manager

  on_mount {AshPhoenixStarterWeb.LiveUserAuth, :live_user_required}

  @providers [
    {"Local Disk (Default)", "local"},
    {"AWS S3", "s3"},
    {"Cloudflare R2", "r2"},
    {"DigitalOcean Spaces", "spaces"},
    {"MinIO (Self-Hosted)", "minio"}
  ]

  @image_modes [
    {"Local", "local"},
    {"CDN / Cloud", "cdn"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    org_id = resolve_user_org_uuid(socket.assigns.current_user)

    socket =
      socket
      |> assign(:organization_id, org_id)
      |> assign(:active_tab, if(org_id, do: :storage, else: :global))
      |> assign(:providers, @providers)
      |> assign(:image_modes, @image_modes)
      |> assign(:storage_form, to_form(load_storage_settings(org_id), as: :storage))
      |> assign(:global_form, to_form(load_global_settings(), as: :global))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6 space-y-6">
      <div>
        <h1 class="text-2xl font-bold">System & Storage Settings</h1>
        <p class="text-sm opacity-70">
          Manage tenant-specific storage backends and global application configuration.
        </p>
      </div>

      <%!-- Tabs --%>
      <div role="tablist" class="tabs tabs-boxed w-fit">
        <button
          :if={@organization_id}
          type="button"
          role="tab"
          phx-click="switch_tab"
          phx-value-tab="storage"
          class={["tab", @active_tab == :storage && "tab-active"]}
        >
          Organization Storage
        </button>
        <button
          type="button"
          role="tab"
          phx-click="switch_tab"
          phx-value-tab="global"
          class={["tab", @active_tab == :global && "tab-active"]}
        >
          Global App Settings
        </button>
      </div>

      <%!-- TAB 1: ORGANIZATION STORAGE SETTINGS --%>
      <%= if @active_tab == :storage and @organization_id do %>
        <.form
          for={@storage_form}
          id="storage-settings-form"
          phx-change="validate_storage"
          phx-submit="save_storage"
          class="card bg-base-100 border border-base-300 shadow-sm"
        >
          <div class="card-body space-y-5">
            <h2 class="card-title text-lg">Tenant Storage Backend</h2>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Storage Provider</span>
              </label>
              <select
                name={@storage_form[:storage_provider].name}
                id={@storage_form[:storage_provider].id}
                class="select select-bordered w-full"
              >
                <%= Phoenix.HTML.Form.options_for_select(
                  @providers,
                  @storage_form[:storage_provider].value
                ) %>
              </select>
            </div>

            <%= if @storage_form[:storage_provider].value != "local" do %>
              <div class="divider text-xs opacity-60">S3-Compatible Connection Details</div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-medium">Bucket Name</span>
                  </label>
                  <input
                    type="text"
                    name={@storage_form[:storage_bucket].name}
                    value={@storage_form[:storage_bucket].value}
                    placeholder="my-org-uploads"
                    class="input input-bordered w-full"
                    required
                  />
                </div>

                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-medium">Endpoint Host</span>
                  </label>
                  <input
                    type="text"
                    name={@storage_form[:storage_host].name}
                    value={@storage_form[:storage_host].value}
                    placeholder={host_placeholder(@storage_form[:storage_provider].value)}
                    class="input input-bordered w-full"
                  />
                </div>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-medium">Access Key ID</span>
                  </label>
                  <input
                    type="text"
                    name={@storage_form[:storage_access_key].name}
                    value={@storage_form[:storage_access_key].value}
                    placeholder="AKIA..."
                    autocomplete="off"
                    class="input input-bordered w-full font-mono text-sm"
                  />
                </div>

                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-medium">Secret Access Key</span>
                  </label>
                  <input
                    type="password"
                    name={@storage_form[:storage_secret_key].name}
                    value={@storage_form[:storage_secret_key].value}
                    placeholder={
                      if @storage_form[:has_secret_key?].value,
                        do: "•••••••••••••••• (leave blank to keep)",
                        else: "Enter secret access key"
                    }
                    autocomplete="new-password"
                    class="input input-bordered w-full font-mono text-sm"
                  />
                </div>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text font-medium">Public CDN Base URL (Optional)</span>
                </label>
                <input
                  type="url"
                  name={@storage_form[:storage_cdn_url].name}
                  value={@storage_form[:storage_cdn_url].value}
                  placeholder="https://yourdomain.com"
                  class="input input-bordered w-full"
                />
                <label class="label">
                  <span class="label-text-alt opacity-70">
                    Overrides generated bucket URLs when serving public links.
                  </span>
                </label>
              </div>

              <div class="form-control">
                <label class="label cursor-pointer justify-start gap-3">
                  <input type="hidden" name={@storage_form[:storage_virtual_host].name} value="false" />
                  <input
                    type="checkbox"
                    name={@storage_form[:storage_virtual_host].name}
                    value="true"
                    checked={truthy?(@storage_form[:storage_virtual_host].value)}
                    class="checkbox checkbox-primary"
                  />
                  <div>
                    <span class="label-text font-medium">Use Virtual-Hosted Style URLs</span>
                    <p class="text-xs opacity-70">
                      Enabled: <code>bucket.host/key</code> (recommended for R2/AWS).
                      Disabled: <code>host/bucket/key</code> (recommended for MinIO).
                    </p>
                  </div>
                </label>
              </div>
            <% end %>

            <div class="card-actions justify-end pt-4 border-t border-base-200">
              <button type="submit" class="btn btn-primary">
                Save Storage Settings
              </button>
            </div>
          </div>
        </.form>
      <% end %>

      <%!-- TAB 2: GLOBAL APPLICATION SETTINGS --%>
      <%= if @active_tab == :global do %>
        <.form
          for={@global_form}
          id="global-settings-form"
          phx-submit="save_global"
          class="card bg-base-100 border border-base-300 shadow-sm"
        >
          <div class="card-body space-y-5">
            <h2 class="card-title text-lg">Global Application Settings</h2>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="form-control">
                <label class="label">
                  <span class="label-text font-medium">Image Delivery Mode</span>
                </label>
                <select
                  name={@global_form[:image_mode].name}
                  class="select select-bordered w-full"
                >
                  <%= Phoenix.HTML.Form.options_for_select(
                    @image_modes,
                    @global_form[:image_mode].value
                  ) %>
                </select>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text font-medium">Max Upload Size (MB)</span>
                </label>
                <input
                  type="number"
                  min="1"
                  max="10240"
                  name={@global_form[:max_upload_mb].name}
                  value={@global_form[:max_upload_mb].value}
                  class="input input-bordered w-full"
                  required
                />
              </div>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-3">
                <input type="hidden" name={@global_form[:maintenance_mode].name} value="false" />
                <input
                  type="checkbox"
                  name={@global_form[:maintenance_mode].name}
                  value="true"
                  checked={truthy?(@global_form[:maintenance_mode].value)}
class="checkbox checkbox-warning"
/>

Maintenance Mode

Temporarily pause non-admin operations across the application.



Save Global Settings



</.form>
<% end %>

"""
end

============================================================================


EVENTS


============================================================================

@impl true
def handle_event("switch_tab", %{"tab" => "storage"}, socket) do
{:noreply, assign(socket, :active_tab, :storage)}
end
def handle_event("switch_tab", %{"tab" => "global"}, socket) do
{:noreply, assign(socket, :active_tab, :global)}
end
@impl true
def handle_event("validate_storage", %{"storage" => params}, socket) do
current_provider = socket.assigns.storage_form[:storage_provider].value
params =
if params["storage_provider"] != current_provider do
Map.put(params, "storage_virtual_host", to_string(params["storage_provider"] == "r2"))
else
params
end
params = Map.put(params, "has_secret_key?", socket.assigns.storage_form[:has_secret_key?].value)
{:noreply, assign(socket, :storage_form, to_form(params, as: :storage))}
end
@impl true
def handle_event("save_storage", %{"storage" => params}, socket) do
org_id = socket.assigns.organization_id
case persist_storage_settings(org_id, params) do
:ok ->
reloaded = load_storage_settings(org_id)
{:noreply,
socket
|> assign(:storage_form, to_form(reloaded, as: :storage))
|> put_flash(:info, "Organization storage settings saved.")}
{:error, reason} ->
{:noreply, put_flash(socket, :error, "Failed to save storage settings: #{inspect(reason)}")}
end
end
@impl true
def handle_event("save_global", %{"global" => params}, socket) do
case persist_global_settings(params) do
:ok ->
reloaded = load_global_settings()
{:noreply,
socket
|> assign(:global_form, to_form(reloaded, as: :global))
|> put_flash(:info, "Global settings saved.")}
{:error, reason} ->
{:noreply, put_flash(socket, :error, "Failed to save global settings: #{inspect(reason)}")}
end
end

============================================================================


PERSISTENCE & LOADING HELPERS


============================================================================

defp load_storage_settings(nil), do: %{}
defp load_storage_settings(org_id) do
provider = Manager.get_tenant(org_id, :storage_provider) || "local"
existing_secret = Manager.get_tenant(org_id, :storage_secret_key)
virtual_host =
case Manager.get_tenant(org_id, :storage_virtual_host) do
val when is_boolean(val) -> val
_ -> provider == "r2"
end
%{
"storage_provider" => provider,
"storage_bucket" => Manager.get_tenant(org_id, :storage_bucket) || "",
"storage_host" => Manager.get_tenant(org_id, :storage_host) || "",
"storage_access_key" => Manager.get_tenant(org_id, :storage_access_key) || "",
"storage_secret_key" => "",
"has_secret_key?" => is_binary(existing_secret) and existing_secret != "",
"storage_cdn_url" => Manager.get_tenant(org_id, :storage_cdn_url) || "",
"storage_virtual_host" => virtual_host
}
end
defp persist_storage_settings(org_id, params) do
entries = [
{:storage_provider, params["storage_provider"] || "local", "string"},
{:storage_bucket, clean_string(params["storage_bucket"]), "string"},
{:storage_host, clean_string(params["storage_host"]), "string"},
{:storage_access_key, clean_string(params["storage_access_key"]), "string"},
{:storage_cdn_url, clean_string(params["storage_cdn_url"]), "string"},
{:storage_virtual_host, truthy?(params["storage_virtual_host"]), "boolean"}
]
entries =
case clean_string(params["storage_secret_key"]) do
"" -> entries
new_secret -> [{:storage_secret_key, new_secret, "string"} | entries]
end
Enum.reduce_while(entries, :ok, fn {key, val, type}, :ok ->
case Manager.put_tenant(org_id, key, val, type) do
{:ok, _} -> {:cont, :ok}
{:error, reason} -> {:halt, {:error, reason}}
end
end)
end
defp load_global_settings do
max_bytes = Manager.get(:max_upload_size) || 500 * 1024 * 1024
image_mode = Manager.get(:image_mode) || :local
maintenance = Manager.get(:maintenance_mode) || false
%{
"image_mode" => to_string(image_mode),
"max_upload_mb" => div(max_bytes, 1024 * 1024),
"maintenance_mode" => maintenance
}
end
defp persist_global_settings(params) do
max_mb =
case Integer.parse(to_string(params["max_upload_mb"] || "500")) do
{num, _} when num > 0 -> num
_ -> 500
end
image_mode =
case params["image_mode"] do
"cdn" -> :cdn
_ -> :local
end
entries = [
{:image_mode, image_mode, "atom"},
{:max_upload_size, max_mb * 1024 * 1024, "integer"},
{:maintenance_mode, truthy?(params["maintenance_mode"]), "boolean"}
]
Enum.reduce_while(entries, :ok, fn {key, val, type}, :ok ->
case Manager.put(key, val, type) do
{:ok, _} -> {:cont, :ok}
{:error, reason} -> {:halt, {:error, reason}}
end
end)
end

============================================================================


UTILITIES


============================================================================


Setting & TenantConfiguration require non-nil :value strings (allow_nil?: false),


so blank inputs are normalized to a single space or non-empty sentinel if needed,


or stored as "-" / trimmed string. Using String.trim/1 keeps valid strings clean.

defp clean_string(nil), do: " "
defp clean_string(val) when is_binary(val) do
case String.trim(val) do
"" -> " "
trimmed -> trimmed
end
end
defp truthy?(val) when val in [true, "true", "on", "1"], do: true
defp truthy?(_), do: false
defp host_placeholder("r2"), do: "<account_id>.r2.cloudflarestorage.com"
defp host_placeholder("minio"), do: "localhost:9000"
defp host_placeholder("spaces"), do: "digitaloceanspaces.com"
defp host_placeholder("s3"), do: "amazonaws.com"
defp host_placeholder(_), do: ""
defp resolve_user_org_uuid(%{organization: %{id: org_id}}) when is_binary(org_id), do: org_id
defp resolve_user_org_uuid(%{current_organization: domain} = user) when is_binary(domain) do
case Ash.load(user, :organization, actor: user) do
{:ok, %{organization: %{id: org_id}}} -> org_id
_ -> nil
end
end
defp resolve_user_org_uuid(_), do: nil
end

