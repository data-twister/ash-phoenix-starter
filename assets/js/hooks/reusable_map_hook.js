/**
 * assets/js/reusable_map_hook.js
 * 
 * Reusable Leaflet integration hook for Phoenix LiveView.
 * This hook is completely decoupled from any specific country or hardcoded datasets.
 */
export default {
  mounted() {
    // 1. Initialize Map Instance
    const map = L.map(this.el.id).setView([0, 0], 2);
    let currentGeoJsonLayer = null;
    let layerLookupIndex = {};

    // 2. Load Base Tile Layer Map Graphics
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://openstreetmap.org">OpenStreetMap</a> contributors'
    }).addTo(map);

    // 3. Information HUD Control Overlay Panel
    const info = L.control();

    info.onAdd = function (map) {
      this._div = L.DomUtil.create('div', 'info');
      this._div.style.backgroundColor = 'rgba(255, 255, 255, 0.96)';
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
        ? `<b style="font-size: 14px; color: #111827;">${props.name}</b><br /><span style="color: #4b5563;">Total Product Stock:</span> <strong style="color: #111827;">${props.density.toLocaleString() || 0} units</strong>` 
        : '<span style="color: #6b7280;">Hover over a region</span>';
      this._div.innerHTML = `<h4 style="margin: 0 0 6px 0; font-size: 12px; text-transform: uppercase; letter-spacing: 0.05em; color: #6b7280;">Inventory Health</h4>${contents}`;
    };

    info.addTo(map);

    // 4. Uniform Dynamic Color Scales Handler
    // UPDATED: Adjusted scale steps to align with product catalog volume thresholds
    function getColor(stockLevel) {
      if (stockLevel > 2000)  return '#10b981'; // Healthy Inventory: Above Low Threshold (Green)
      if (stockLevel > 500)   return '#f59e0b'; // Warning: Low Stock Threshold breached (Yellow/Orange)
      if (stockLevel > 0)     return '#ef4444'; // Alert: Critical Stock Threshold breached (Red)
      return '#e5e7eb';                         // Out of Stock / No Registered Products (Gray)
    }

    function style(feature) {
      const stock = feature.properties.density || 0;
      return {
        weight: 1.5,
        opacity: 0.9,
        dashArray: '3',
        fillOpacity: 0.65,
        fillColor: getColor(stock),
        color: '#ffffff'
      };
    }

    // 5. Interactive Layer Callbacks Engine
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

    // FIXED: Patched variable layout assignments to ensure smooth tracking boundaries
    function resetHighlight(e) {
      if (currentGeoJsonLayer) {
        currentGeoJsonLayer.resetStyle(e.target);
      }
      info.update();
    }

    // Automatically centers and zooms into clicked territories smoothly
    function zoomToFeature(e) {
      map.fitBounds(e.target.getBounds());
    }

    function onEachFeature(feature, layer) {
      if (feature.properties && feature.properties.name) {
        const cleanName = feature.properties.name.toLowerCase().trim();
        layerLookupIndex[cleanName] = layer;
      }

      layer.on({
        mouseover: highlightFeature,
        mouseout: resetHighlight,
        click: zoomToFeature
      });
    }

    // 6. Centralized Core Rendering Pipeline
    const renderLayerPipeline = (geoJsonData) => {
      if (!geoJsonData || !geoJsonData.features) return;

      if (currentGeoJsonLayer) {
        map.removeLayer(currentGeoJsonLayer);
      }

      layerLookupIndex = {};

      currentGeoJsonLayer = L.geoJson(geoJsonData, {
        style: style,
        onEachFeature: onEachFeature
      }).addTo(map);

      if (currentGeoJsonLayer.getBounds().isValid()) {
        map.fitBounds(currentGeoJsonLayer.getBounds(), { padding: [30, 30] });
      }
    };

    // 7. Initial Startup Processing Execution Call
    if (this.el.dataset.geojson) {
      try {
        const payload = JSON.parse(this.el.dataset.geojson);
        renderLayerPipeline(payload);
      } catch (err) {
        console.error("Reusable Map Hook initialization parameter sequence processing failure:", err);
      }
    }

    // 8. SERVER-DRIVEN INTERACTION LISTENER: Renders a completely new country layout dynamically
    this.handleEvent("render_new_layer", ({ geojson }) => {
      renderLayerPipeline(geojson);
    });

    // 9. ATOMIC METRIC UPDATE LISTENER: Real-time Live Updates for individual states/provinces
    this.handleEvent("update_stock", ({ province_name, new_stock }) => {
      if (!province_name) return;

      const targetLayer = layerLookupIndex[province_name.toLowerCase().trim()];
      if (targetLayer) {
        targetLayer.feature.properties.density = new_stock;

        targetLayer.setStyle({
          fillColor: getColor(new_stock)
        });

        // Update active tracking HUD if the user is currently hovering over this updating segment
        info.update(targetLayer.feature.properties);
      }
    });
  }
}
