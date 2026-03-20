(function() {
    // BulkPlainTshirt.com — Live Warehouse Feed Button Widget
    // Add this script to your main website to show a LIVE button
    // Usage: <script src="https://live.sale91.com/live-button.js"></script>

    var LIVE_URL = "https://live.sale91.com/warehouse-live.html";

    // Inject CSS
    var style = document.createElement("style");
    style.textContent = [
        /* Floating LIVE button — fixed bottom-left, above WhatsApp */
        ".bpt-live-float {",
        "  position: fixed;",
        "  bottom: 80px;",
        "  left: 18px;",
        "  z-index: 9999;",
        "  display: flex;",
        "  align-items: center;",
        "  gap: 8px;",
        "  background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%);",
        "  color: #fff;",
        "  padding: 12px 20px;",
        "  border-radius: 50px;",
        "  cursor: pointer;",
        "  text-decoration: none;",
        "  font-family: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;",
        "  font-size: 14px;",
        "  font-weight: 700;",
        "  letter-spacing: 0.05em;",
        "  box-shadow: 0 4px 20px rgba(220, 38, 38, 0.4), 0 2px 8px rgba(0,0,0,0.3);",
        "  transition: transform 0.2s ease, box-shadow 0.2s ease;",
        "  animation: bpt-live-entrance 0.5s ease-out;",
        "}",
        ".bpt-live-float:hover {",
        "  transform: scale(1.08);",
        "  box-shadow: 0 6px 28px rgba(220, 38, 38, 0.55), 0 4px 12px rgba(0,0,0,0.3);",
        "}",
        ".bpt-live-float:active {",
        "  transform: scale(0.97);",
        "}",

        /* Red pulsing dot */
        ".bpt-live-dot {",
        "  width: 10px;",
        "  height: 10px;",
        "  background: #dc2626;",
        "  border-radius: 50%;",
        "  animation: bpt-pulse 1.5s infinite;",
        "  flex-shrink: 0;",
        "}",

        /* Outer glow ring */
        ".bpt-live-ring {",
        "  position: relative;",
        "  width: 18px;",
        "  height: 18px;",
        "  display: flex;",
        "  align-items: center;",
        "  justify-content: center;",
        "  flex-shrink: 0;",
        "}",
        ".bpt-live-ring::before {",
        "  content: '';",
        "  position: absolute;",
        "  inset: 0;",
        "  border-radius: 50%;",
        "  background: rgba(220, 38, 38, 0.25);",
        "  animation: bpt-ring 2s infinite;",
        "}",

        /* Text label */
        ".bpt-live-label {",
        "  display: flex;",
        "  flex-direction: column;",
        "  line-height: 1.2;",
        "}",
        ".bpt-live-label span:first-child {",
        "  font-size: 14px;",
        "  font-weight: 800;",
        "  letter-spacing: 0.08em;",
        "}",
        ".bpt-live-label span:last-child {",
        "  font-size: 10px;",
        "  font-weight: 500;",
        "  color: #ccc;",
        "  letter-spacing: 0.02em;",
        "}",

        /* Camera icon */
        ".bpt-live-cam {",
        "  width: 20px;",
        "  height: 20px;",
        "  flex-shrink: 0;",
        "  opacity: 0.9;",
        "}",

        /* Animations */
        "@keyframes bpt-pulse {",
        "  0%, 100% { opacity: 1; transform: scale(1); }",
        "  50% { opacity: 0.4; transform: scale(0.85); }",
        "}",
        "@keyframes bpt-ring {",
        "  0% { transform: scale(1); opacity: 0.5; }",
        "  100% { transform: scale(2.2); opacity: 0; }",
        "}",
        "@keyframes bpt-live-entrance {",
        "  0% { opacity: 0; transform: translateY(20px) scale(0.9); }",
        "  100% { opacity: 1; transform: translateY(0) scale(1); }",
        "}",

        /* Inline button for navbar — sits next to Catalog */
        ".bpt-live-inline {",
        "  display: inline-flex;",
        "  align-items: center;",
        "  gap: 6px;",
        "  background: #dc2626;",
        "  color: #fff;",
        "  padding: 8px 16px;",
        "  border-radius: 8px;",
        "  cursor: pointer;",
        "  text-decoration: none;",
        "  font-family: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;",
        "  font-size: 14px;",
        "  font-weight: 700;",
        "  letter-spacing: 0.05em;",
        "  transition: background 0.2s ease;",
        "  vertical-align: middle;",
        "}",
        ".bpt-live-inline:hover {",
        "  background: #b91c1c;",
        "}",
        ".bpt-live-inline .bpt-live-dot {",
        "  width: 8px;",
        "  height: 8px;",
        "}",

        /* Mobile responsive */
        "@media (max-width: 480px) {",
        "  .bpt-live-float {",
        "    bottom: 75px;",
        "    left: 14px;",
        "    padding: 10px 16px;",
        "    font-size: 13px;",
        "  }",
        "  .bpt-live-label span:last-child {",
        "    font-size: 9px;",
        "  }",
        "}"
    ].join("\n");
    document.head.appendChild(style);

    // Create floating LIVE button
    var btn = document.createElement("a");
    btn.href = LIVE_URL;
    btn.target = "_blank";
    btn.className = "bpt-live-float";
    btn.setAttribute("aria-label", "Watch our warehouse live feed");
    btn.setAttribute("title", "Watch our warehouse LIVE — 24/7 real-time feed");
    btn.innerHTML = [
        '<svg class="bpt-live-cam" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">',
        '  <path d="M23 7l-7 5 7 5V7z"/>',
        '  <rect x="1" y="5" width="15" height="14" rx="2" ry="2"/>',
        '</svg>',
        '<span class="bpt-live-ring"><span class="bpt-live-dot"></span></span>',
        '<span class="bpt-live-label">',
        '  <span>LIVE</span>',
        '  <span>Warehouse Feed</span>',
        '</span>'
    ].join("");

    // Don't show the floating button on the live page itself
    if (window.location.pathname.indexOf("warehouse-live") === -1) {
        // Wait for DOM ready
        if (document.readyState === "loading") {
            document.addEventListener("DOMContentLoaded", function() {
                document.body.appendChild(btn);
            });
        } else {
            document.body.appendChild(btn);
        }
    }

    // Also try to inject an inline button next to Catalog if navbar exists
    function tryInjectInline() {
        // Look for common navbar patterns — the Catalog link
        var catalogLinks = document.querySelectorAll('a[href*="catalog"], a[href*="Catalog"]');
        var injected = false;
        for (var i = 0; i < catalogLinks.length; i++) {
            var link = catalogLinks[i];
            // Only inject next to visible, top-level catalog buttons
            if (link.offsetParent !== null && !injected) {
                var inlineBtn = document.createElement("a");
                inlineBtn.href = LIVE_URL;
                inlineBtn.target = "_blank";
                inlineBtn.className = "bpt-live-inline";
                inlineBtn.setAttribute("title", "Watch our warehouse LIVE");
                inlineBtn.innerHTML = '<span class="bpt-live-dot"></span> LIVE';
                // Insert after the catalog link
                if (link.nextSibling) {
                    link.parentNode.insertBefore(inlineBtn, link.nextSibling);
                } else {
                    link.parentNode.appendChild(inlineBtn);
                }
                injected = true;
            }
        }
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", tryInjectInline);
    } else {
        tryInjectInline();
    }
})();
