defmodule AshPhoenixStarterWeb.Map do
  use AshPhoenixStarterWeb, :html

  @doc """
  A reusable, streaming-ready Leaflet Map component.

  ## Assigns
    * `:initial_geojson` - The pre-hydrated Elixir map structure parsed by the server.
    * `:height` - (Optional) Custom height configuration string. Defaults to "680px".
  """
  def map(assigns) do
    assigns = assign_new(assigns, :height, fn -> "680px" end)

    ~H"""
    <!-- External Leaflet engine assets loaded via CDN to eliminate local file tracking dependencies -->
    <link
      rel="stylesheet"
      href="https://unpkg.com"
      integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY="
      crossorigin=""
    />
    <script
      src="https://unpkg.com"
      integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo="
      crossorigin=""
    >
    </script>

    <!-- Wrapped with phx-update="ignore" to prevent Phoenix from destroying the initialized Leaflet instance -->
    <div id="reusable-map-container" phx-update="ignore">
      <div 
        id="leaflet-reusable-map" 
        phx-hook=".Map" 
        data-geojson={Jason.encode!(@initial_geojson)}
        class="w-full rounded-xl border border-gray-200 shadow-sm" 
        style={"height: #{@height};"}
      ></div>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Map">
      export default {
        mounted() {
          // Initialize map instance targeting a global viewpoint baseline on startup
          const map = L.map('leaflet-reusable-map').setView([0, 0], 2);

          L.tileLayer('https://openstreetmap.org{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="http://openstreetmap.org">OpenStreetMap</a>'
          }).addTo(map);

          // Information HUD display panel overlay
          const info = L.control();

          info.onAdd = function (map) {
            this._div = L.DomUtil.create('div', 'info');
            this._div.style.backgroundColor = 'rgba(255, 255, 255, 0.95)';
            this._div.style.padding = '10px 14px';
            this._div.style.border = '1px solid #d1d5db';
            this._div.style.borderRadius = '6px';
            this._div.style.boxShadow = '0 4px 6px -1px rgba(0, 0, 0, 0.1)';
            this._div.style.fontFamily = 'ui-sans-serif, system-ui, sans-serif';
            this.update();
            return this._div;
          };

          info.update = function (props) {
            const contents = props 
              ? `<b style="font-size: 14px; color: #111827;">${props.name}</b><br /><span style="color: #4b5563;">Stock availability:</span> <strong style="color: #111827;">${props.density || 0}</strong>` 
              : '<span style="color: #6b7280;">Hover over a region</span>';
            this._div.innerHTML = `<h4 style="margin: 0 0 4px 0; font-size: 11px; text-transform: uppercase; letter-spacing: 0.05em; color: #6b7280; font-weight: 600;">Live Metrics</h4>${contents}`;
          };

          info.addTo(map);

          // Add legend overlay for real-time stock alert thresholds
          const legend = L.control({ position: 'bottomright' });
          legend.onAdd = function (map) {
            const div = L.DomUtil.create('div', 'info legend');
            div.style.backgroundColor = 'white';
            div.style.padding = '10px';
            div.style.border = '1px solid #e5e7eb';
            div.style.borderRadius = '6px';
            div.style.fontFamily = 'ui-sans-serif, system-ui, sans-serif';
            div.style.fontSize = '12px';
            div.style.lineHeight = '1.5';
            div.innerHTML += '<strong style="display:block; margin-bottom:4px; color:#374151;">Stock Levels</strong>';
            div.innerHTML += '<i style="background: #ef4444; width: 14px; height: 14px; display: inline-block; margin-right: 6px; vertical-align: middle; border-radius:2px;"></i> Low (&lt;20)<br>';
            div.innerHTML += '<i style="background: #f59e0b; width: 14px; height: 14px; display: inline-block; margin-right: 6px; vertical-align: middle; border-radius:2px;"></i> Medium (20-49)<br>';
            div.innerHTML += '<i style="background: #10b981; width: 14px; height: 14px; display: inline-block; margin-right: 6px; vertical-align: middle; border-radius:2px;"></i> High (50+)<br>';
            return div;
          };
          legend.addTo(map);

          // Standardized dynamic palette hex engine configuration
          function getColor(stockLevel) {
            if (stockLevel >= 50) return '#10b981'; // Green
            if (stockLevel >= 20) return '#f59e0b'; // Yellow
            return '#ef4444';                       // Red
          }

          function style(feature) {
            const stock = feature.properties.density || 0;
            return {
              weight: 1.5,
              opacity: 0.9,
              dashArray: '3',
              fillOpacity: 0.65,
              fillColor: getColor(stock),
              color: '#ffffff' // Crisp white borders separating regional shapes vectors
            };
          }

          function highlightFeature(e) {
            const layer = e.target;
            layer.setStyle({
              weight: 3.5,
              color: '#4b5563',
              dashArray: '',
              fillOpacity: 0.8
            });
            layer.bringToFront();
            info.update(layer.feature.properties);
          }

          function resetHighlight(e) {
            if (currentGeoJsonLayer) {
              currentGeoJsonLayer.resetStyle(e.target);
            }
            info.update();
          }

          function zoomToFeature(e) {
            map.fitBounds(e.target.getBounds());
          }

          // Component state definitions buckets memory slots
          let currentGeoJsonLayer = null;
          let layerLookupIndex = {};

          // Central rendering engine parses, drops, indexes and scales polygon inputs dynamically
          const renderLayerPipeline = (geoJsonData) => {
            if (!geoJsonData || !geoJsonData.features) return;

            // Clear out active layout shapes vectors safely from canvas map context frame
            if (currentGeoJsonLayer) {
              map.removeLayer(currentGeoJsonLayer);
            }
            
            // Clean out local string mapping dictionary lookup indexes completely
            layerLookupIndex = {};

            currentGeoJsonLayer = L.geoJson(geoJsonData, {
              style: style,
              onEachFeature: (feature, layer) => {
                // Pre-index layer paths case-insensitively using the unified server properties block name
                if (feature.properties && feature.properties.name) {
                  const normalizedKey = feature.properties.name.toLowerCase().trim();
                  layerLookupIndex[normalizedKey] = layer;
                }

                layer.on({
                  mouseover: highlightFeature,
                  mouseout: resetHighlight,
                  click: zoomToFeature
                });
              }
            }).addTo(map);

            // Automatically recalibrate and snap map camera bounds framework onto target layout dimensions
            if (currentGeoJsonLayer.getBounds().isValid()) {
              map.fitBounds(currentGeoJsonLayer.getBounds(), { padding: [30, 30] });
            }
          };

          // 1. INITIAL LOAD: Parse and render baseline country passed from component initialization attributes
          if (this.el.dataset.geojson) {
            try {
              const initialPayload = JSON.parse(this.el.dataset.geojson);
              renderLayerPipeline(initialPayload);
            } catch (err) {
              console.error("Component asset JSON parsing failed on initial boot run sequence:", err);
            }
          }

          // 2. RUNTIME EVENT STREAM: Swaps complete geographic coordinate layout profiles (e.g. US -> France)
          this.handleEvent("render_new_layer", ({ geojson }) => {
            renderLayerPipeline(geojson);
          });

          // 3. SOCKET STREAM UPDATE: Catches immediate out-of-band updates sent across your LiveView channel
          this.handleEvent("update_stock", ({ province_name, new_stock }) => {
            if (!province_name) return;

            const targetLayer = layerLookupIndex[province_name.toLowerCase().trim()];
            if (targetLayer) {
              // Inject data changes seamlessly into the active tracking property nodes tree
              targetLayer.feature.properties.density = new_stock;

              // Shift fill colors layout immediately without a slow canvas redraw sequence
              targetLayer.setStyle({
                fillColor: getColor(new_stock)
              });

              // Instantly update layout tooltips content pane values if currently hovered by the user
              info.update(targetLayer.feature.properties);
            }
          });
        }
      }
    </script>
    """
  end
end
