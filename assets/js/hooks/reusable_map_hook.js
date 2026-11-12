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
    const pinsLayer = L.layerGroup().addTo(map);

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
        ? `<b style="font-size: 14px; color: #111827;">${props.name}</b><br /><span style="color: #4b5563;">Total Product Stock:</span> <strong style="color: #111827;">${(props.density || 0).toLocaleString()} units</strong>`
        : '<span style="color: #6b7280;">Hover over a region or click a pin</span>';

      const legend = `
        <div style="margin-top: 8px; padding-top: 6px; border-top: 1px solid #e5e7eb; display: flex; gap: 10px; font-size: 11px; color: #4b5563;">
          <span style="display: inline-flex; align-items: center; gap: 4px;">
            <span style="width: 8px; height: 8px; border-radius: 9999px; background: #2563eb; display: inline-block;"></span>
            Vendor
          </span>
          <span style="display: inline-flex; align-items: center; gap: 4px;">
            <span style="width: 8px; height: 8px; border-radius: 9999px; background: #d97706; display: inline-block;"></span>
            Merchant
          </span>
        </div>
      `;

      this._div.innerHTML = `<h4 style="margin: 0 0 6px 0; font-size: 12px; text-transform: uppercase; letter-spacing: 0.05em; color: #6b7280;">Inventory Health</h4>${contents}${legend}`;
    };

    info.addTo(map);

    // 4. Uniform Dynamic Color Scales Handler
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

      // Keep location pins above hovered territory polygons so popups stay clickable
      pinsLayer.eachLayer((pin) => {
        if (pin.bringToFront) pin.bringToFront();
      });

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

      pinsLayer.eachLayer((pin) => {
        if (pin.bringToFront) pin.bringToFront();
      });

      if (currentGeoJsonLayer.getBounds().isValid()) {
        map.fitBounds(currentGeoJsonLayer.getBounds(), { padding: [30, 30] });
      }
    };

       // 7. Vendor & Merchant RegionLocation Pins Pipeline
    const renderPinsPipeline = (pins) => {
      pinsLayer.clearLayers();
      if (!Array.isArray(pins)) return;

      pins.forEach((pin) => {
        if (pin.lat == null || pin.lng == null) return;

        const isVendor = pin.type === "vendor";
        const color = isVendor ? "#2563eb" : "#d97706";
        const badgeLabel = isVendor ? "Vendor" : "Merchant";
        const filterParam = isVendor ? "vendor_id" : "merchant_id";
        const resourcePath = isVendor ? "vendors" : "merchants";

        const productsUrl = pin.id
          ? `/products?${filterParam}=${encodeURIComponent(pin.id)}`
          : "/products";
        const editUrl = pin.id
          ? `/${resourcePath}/${encodeURIComponent(pin.id)}/edit`
          : null;

        const editLinkHtml = editUrl
          ? `<a
               href="${editUrl}"
               data-phx-link="redirect"
               data-phx-link-state="push"
               style="font-size: 12px; font-weight: 500; color: #4b5563; text-decoration: underline;"
             >
               Edit
             </a>`
          : "";

        const marker = L.circleMarker([pin.lat, pin.lng], {
          radius: 7,
          fillColor: color,
          color: "#ffffff",
          weight: 2,
          opacity: 1,
          fillOpacity: 0.95
        });

        marker.bindPopup(`
          <div style="font-family: ui-sans-serif, system-ui, sans-serif; font-size: 13px; line-height: 1.4;">
            <span style="font-weight: 700; color: ${color}; text-transform: uppercase; font-size: 10px; letter-spacing: 0.05em;">
              ${badgeLabel}
            </span><br/>
            <strong style="color: #111827;">${pin.name}</strong><br/>
            <span style="color: #4b5563;">${pin.region_name} &middot; ${pin.code}</span>
            <div style="margin-top: 6px; padding-top: 6px; border-top: 1px solid #e5e7eb; display: flex; align-items: center; justify-content: space-between; gap: 12px;">
              <a
                href="${productsUrl}"
                data-phx-link="redirect"
                data-phx-link-state="push"
                style="font-size: 12px; font-weight: 600; color: ${color}; text-decoration: underline;"
              >
                View products &rarr;
              </a>
              ${editLinkHtml}
            </div>
          </div>
        `);

        marker.addTo(pinsLayer);
      });
    };


    // 8. Initial Startup Processing Execution Call
    if (this.el.dataset.geojson) {
      try {
        const payload = JSON.parse(this.el.dataset.geojson);
        renderLayerPipeline(payload);
      } catch (err) {
        console.error("Reusable Map Hook initialization parameter sequence processing failure:", err);
      }
    }

    if (this.el.dataset.pins) {
      try {
        const initialPins = JSON.parse(this.el.dataset.pins);
        renderPinsPipeline(initialPins);
      } catch (err) {
        console.error("Reusable Map Hook pins initialization failure:", err);
      }
    }

    // 9. SERVER-DRIVEN INTERACTION LISTENERS
    this.handleEvent("render_new_layer", ({ geojson }) => {
      renderLayerPipeline(geojson);
    });

    this.handleEvent("update_pins", ({ pins }) => {
      renderPinsPipeline(pins);
    });

    // 10. ATOMIC METRIC UPDATE LISTENER: Real-time Live Updates for individual states/provinces
    this.handleEvent("update_stock", ({ province_name, new_stock }) => {
      if (!province_name) return;

      const targetLayer = layerLookupIndex[province_name.toLowerCase().trim()];
      if (targetLayer) {
        targetLayer.feature.properties.density = new_stock;

        targetLayer.setStyle({
          fillColor: getColor(new_stock)
        });

        info.update(targetLayer.feature.properties);
      }
    });
  }
};
