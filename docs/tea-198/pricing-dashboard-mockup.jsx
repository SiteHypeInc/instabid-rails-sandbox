import { useState } from "react";

const PRICING_DATA = {
  plumbing: {
    name: "Plumbing",
    icon: "🔧",
    sections: [
      {
        title: "Labor Rates",
        type: "LABOR_RATE",
        typeLabel: "Hourly Rate — what you charge per hour",
        typeColor: "#f59e0b",
        items: [
          { key: "plumb_labor_rate", label: "Standard Labor", value: 95, unit: "/hr" },
          { key: "plumb_labor_emergency", label: "Emergency Labor", value: 175, unit: "/hr" },
          { key: "plumb_service_call", label: "Service Call Fee", value: 95, unit: "flat" },
        ]
      },
      {
        title: "Fixture Installation",
        type: "INSTALLED",
        typeLabel: "Installed Price — includes basic materials + install labor",
        typeColor: "#06b6d4",
        syncable: true,
        items: [
          { key: "plumb_toilet", label: "Toilet Install", value: 375, unit: "each", materialPart: 248, laborPart: 127, hdSku: "301469892" },
          { key: "plumb_sink_bath", label: "Bathroom Sink Install", value: 350, unit: "each", materialPart: 148, laborPart: 202, hdSku: "304845716" },
          { key: "plumb_sink_kitchen", label: "Kitchen Sink Install", value: 550, unit: "each", materialPart: 298, laborPart: 252, hdSku: "202084619" },
          { key: "plumb_faucet_bath", label: "Bathroom Faucet Install", value: 225, unit: "each", materialPart: 100, laborPart: 125 },
          { key: "plumb_faucet_kitchen", label: "Kitchen Faucet Install", value: 300, unit: "each", materialPart: 164, laborPart: 136, hdSku: "309847251" },
          { key: "plumb_shower_valve", label: "Shower Valve Install", value: 450, unit: "each", materialPart: 224, laborPart: 226, hdSku: "304562981" },
          { key: "plumb_tub", label: "Tub Install", value: 1200, unit: "each", materialPart: 600, laborPart: 600 },
          { key: "plumb_dishwasher", label: "Dishwasher Hookup", value: 200, unit: "each", materialPart: 50, laborPart: 150 },
          { key: "plumb_garbage_disposal", label: "Garbage Disposal Install", value: 325, unit: "each", materialPart: 99, laborPart: 226, hdSku: "INSINKERATOR-B400" },
          { key: "plumb_ice_maker", label: "Ice Maker Line", value: 150, unit: "each", materialPart: 25, laborPart: 125 },
        ]
      },
      {
        title: "Water Heaters",
        type: "INSTALLED",
        typeLabel: "Installed Price — unit + install labor",
        typeColor: "#06b6d4",
        syncable: true,
        items: [
          { key: "plumb_heater_tank_40", label: "Tank 40 gal", value: 1200, unit: "each", materialPart: 647, laborPart: 553, hdSku: "311467890" },
          { key: "plumb_heater_tank_50", label: "Tank 50 gal", value: 1600, unit: "each", materialPart: 847, laborPart: 753, hdSku: "312558947" },
          { key: "plumb_heater_tankless_gas", label: "Tankless Gas", value: 3500, unit: "each", materialPart: 1247, laborPart: 2253, hdSku: "313847629" },
          { key: "plumb_heater_tankless_elec", label: "Tankless Electric", value: 2200, unit: "each", materialPart: 900, laborPart: 1300 },
        ]
      },
      {
        title: "Water Systems",
        type: "INSTALLED",
        typeLabel: "Installed Price — equipment + install labor",
        typeColor: "#06b6d4",
        items: [
          { key: "plumb_water_softener", label: "Water Softener Install", value: 1800, unit: "each", materialPart: 800, laborPart: 1000 },
          { key: "plumb_sump_pump", label: "Sump Pump Install", value: 650, unit: "each", materialPart: 250, laborPart: 400 },
        ]
      },
      {
        title: "Repipe",
        type: "MATERIAL",
        typeLabel: "Material Only — labor calculated separately from labor rate × hours",
        typeColor: "#10b981",
        syncable: true,
        items: [
          { key: "plumb_repipe_pex_lf", label: "PEX Pipe", value: 2.50, unit: "/lf", hdSku: "203668668" },
          { key: "plumb_repipe_copper_lf", label: "Copper Pipe", value: 4.50, unit: "/lf", hdSku: "100134510" },
        ]
      },
      {
        title: "Major Jobs",
        type: "LUMP_SUM",
        typeLabel: "Flat Rate — fixed price regardless of specifics",
        typeColor: "#8b5cf6",
        items: [
          { key: "plumb_main_line", label: "Main Line Replacement", value: 1200, unit: "flat" },
          { key: "plumb_gas_line_new", label: "New Gas Line", value: 500, unit: "flat" },
        ]
      },
      {
        title: "Access Type Multipliers",
        type: "MULTIPLIER",
        typeLabel: "Multiplier — adjusts total cost, not a dollar amount",
        typeColor: "#ef4444",
        items: [
          { key: "plumb_access_basement", label: "Basement (easy)", value: 1.0, unit: "×" },
          { key: "plumb_access_crawlspace", label: "Crawlspace", value: 1.15, unit: "×" },
          { key: "plumb_access_slab", label: "Slab (hardest)", value: 1.35, unit: "×" },
        ]
      },
      {
        title: "Water Heater Location Multipliers",
        type: "MULTIPLIER",
        typeLabel: "Multiplier — adjusts water heater install cost",
        typeColor: "#ef4444",
        items: [
          { key: "plumb_location_garage", label: "Garage", value: 1.0, unit: "×" },
          { key: "plumb_location_basement", label: "Basement", value: 1.0, unit: "×" },
          { key: "plumb_location_closet", label: "Closet", value: 1.1, unit: "×" },
          { key: "plumb_location_attic", label: "Attic (hardest)", value: 1.25, unit: "×" },
        ]
      }
    ]
  }
};

const TYPE_BADGES = {
  LABOR_RATE: { bg: "#f59e0b20", border: "#f59e0b", text: "#f59e0b", label: "LABOR" },
  INSTALLED: { bg: "#06b6d420", border: "#06b6d4", text: "#06b6d4", label: "INSTALLED" },
  MATERIAL: { bg: "#10b98120", border: "#10b981", text: "#10b981", label: "MATERIAL ONLY" },
  LUMP_SUM: { bg: "#8b5cf620", border: "#8b5cf6", text: "#8b5cf6", label: "FLAT RATE" },
  MULTIPLIER: { bg: "#ef444420", border: "#ef4444", text: "#ef4444", label: "MULTIPLIER" },
};

function TypeBadge({ type }) {
  const style = TYPE_BADGES[type];
  return (
    <span style={{
      display: "inline-flex",
      alignItems: "center",
      gap: 4,
      padding: "2px 10px",
      borderRadius: 20,
      fontSize: 11,
      fontWeight: 700,
      letterSpacing: "0.05em",
      background: style.bg,
      border: `1px solid ${style.border}`,
      color: style.text,
    }}>
      {style.label}
    </span>
  );
}

function SyncIndicator({ hdSku }) {
  if (!hdSku) return <span style={{ fontSize: 11, color: "#64748b" }}>Manual</span>;
  return (
    <span style={{
      display: "inline-flex",
      alignItems: "center",
      gap: 4,
      fontSize: 11,
      color: "#10b981",
      fontWeight: 600,
    }}>
      <span style={{ width: 6, height: 6, borderRadius: "50%", background: "#10b981", display: "inline-block" }} />
      HD Live
    </span>
  );
}

function PricingItem({ item, type, showBreakdown }) {
  const isInstalled = type === "INSTALLED";
  const isMultiplier = type === "MULTIPLIER";

  return (
    <div style={{
      background: "#0f172a",
      border: "1px solid #1e293b",
      borderRadius: 10,
      padding: "14px 16px",
      display: "flex",
      flexDirection: "column",
      gap: 8,
      transition: "border-color 0.2s",
    }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <span style={{ fontSize: 13, color: "#94a3b8", fontWeight: 500 }}>{item.label}</span>
        <SyncIndicator hdSku={item.hdSku} />
      </div>

      <div style={{ display: "flex", alignItems: "baseline", gap: 6 }}>
        {!isMultiplier && <span style={{ fontSize: 12, color: "#64748b" }}>$</span>}
        <span style={{
          fontSize: 26,
          fontWeight: 700,
          color: "#e2e8f0",
          fontFamily: "'JetBrains Mono', 'SF Mono', monospace",
        }}>
          {isMultiplier ? item.value.toFixed(2) : item.value.toLocaleString("en-US", { minimumFractionDigits: item.value % 1 ? 2 : 0 })}
        </span>
        <span style={{ fontSize: 12, color: "#64748b" }}>{item.unit}</span>
      </div>

      {isInstalled && showBreakdown && item.materialPart && (
        <div style={{
          display: "flex",
          gap: 8,
          marginTop: 2,
        }}>
          <div style={{
            flex: 1,
            background: "#10b98115",
            border: "1px solid #10b98130",
            borderRadius: 6,
            padding: "6px 8px",
            textAlign: "center",
          }}>
            <div style={{ fontSize: 10, color: "#10b981", fontWeight: 600, marginBottom: 2 }}>MATERIAL</div>
            <div style={{ fontSize: 14, color: "#10b981", fontWeight: 700, fontFamily: "monospace" }}>
              ${item.materialPart}
            </div>
          </div>
          <div style={{
            flex: 1,
            background: "#f59e0b15",
            border: "1px solid #f59e0b30",
            borderRadius: 6,
            padding: "6px 8px",
            textAlign: "center",
          }}>
            <div style={{ fontSize: 10, color: "#f59e0b", fontWeight: 600, marginBottom: 2 }}>LABOR</div>
            <div style={{ fontSize: 14, color: "#f59e0b", fontWeight: 700, fontFamily: "monospace" }}>
              ${item.laborPart}
            </div>
          </div>
        </div>
      )}

      <div style={{ fontSize: 10, color: "#475569", fontFamily: "monospace" }}>
        {item.key}
      </div>
    </div>
  );
}

export default function PricingDashboard() {
  const [showBreakdown, setShowBreakdown] = useState(true);
  const [selectedTrade] = useState("plumbing");
  const trade = PRICING_DATA[selectedTrade];

  const trades = [
    { key: "roofing", label: "Roofing", icon: "🏠" },
    { key: "hvac", label: "HVAC", icon: "❄️" },
    { key: "electrical", label: "Electrical", icon: "⚡" },
    { key: "plumbing", label: "Plumbing", icon: "🔧", active: true },
    { key: "flooring", label: "Flooring", icon: "🪵" },
    { key: "painting", label: "Painting", icon: "🎨" },
    { key: "drywall", label: "Drywall", icon: "🧱" },
    { key: "siding", label: "Siding", icon: "🏗️" },
  ];

  return (
    <div style={{
      minHeight: "100vh",
      background: "#0a0e1a",
      color: "#e2e8f0",
      fontFamily: "'Inter', -apple-system, sans-serif",
      padding: "20px",
    }}>
      {/* Header */}
      <div style={{
        background: "linear-gradient(135deg, #0f172a 0%, #1e293b 100%)",
        borderRadius: 12,
        padding: "20px 24px",
        marginBottom: 20,
        border: "1px solid #1e293b",
      }}>
        <h1 style={{ fontSize: 20, fontWeight: 700, margin: 0, color: "#06b6d4" }}>
          ⚙️ Price Adjustments
        </h1>
        <p style={{ fontSize: 12, color: "#64748b", margin: "4px 0 0" }}>
          Edit your pricing. Each field is labeled with what it represents.
        </p>
      </div>

      {/* Trade tabs */}
      <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 20 }}>
        {trades.map(t => (
          <button key={t.key} style={{
            padding: "8px 16px",
            borderRadius: 20,
            border: t.active ? "2px solid #06b6d4" : "1px solid #1e293b",
            background: t.active ? "#06b6d420" : "#0f172a",
            color: t.active ? "#06b6d4" : "#94a3b8",
            fontSize: 13,
            fontWeight: 600,
            cursor: "pointer",
            display: "flex",
            alignItems: "center",
            gap: 6,
          }}>
            {t.icon} {t.label}
          </button>
        ))}
      </div>

      {/* Legend */}
      <div style={{
        display: "flex",
        flexWrap: "wrap",
        gap: 12,
        marginBottom: 16,
        padding: "12px 16px",
        background: "#0f172a",
        borderRadius: 10,
        border: "1px solid #1e293b",
      }}>
        <span style={{ fontSize: 12, color: "#64748b", fontWeight: 600, marginRight: 4 }}>KEY:</span>
        {Object.entries(TYPE_BADGES).map(([key, val]) => (
          <TypeBadge key={key} type={key} />
        ))}
      </div>

      {/* Toggle */}
      <div style={{
        display: "flex",
        alignItems: "center",
        gap: 10,
        marginBottom: 20,
      }}>
        <button
          onClick={() => setShowBreakdown(!showBreakdown)}
          style={{
            padding: "6px 14px",
            borderRadius: 6,
            border: "1px solid #1e293b",
            background: showBreakdown ? "#06b6d420" : "#0f172a",
            color: showBreakdown ? "#06b6d4" : "#64748b",
            fontSize: 12,
            fontWeight: 600,
            cursor: "pointer",
          }}
        >
          {showBreakdown ? "✓ " : ""}Show Material/Labor Breakdown
        </button>
        <span style={{ fontSize: 11, color: "#475569" }}>
          {showBreakdown ? "Showing what's material vs labor inside installed prices" : "Click to see cost breakdown"}
        </span>
      </div>

      {/* Trade title */}
      <h2 style={{ fontSize: 18, fontWeight: 700, margin: "0 0 20px", display: "flex", alignItems: "center", gap: 8 }}>
        {trade.icon} {trade.name} Pricing
      </h2>

      {/* Sections */}
      {trade.sections.map((section, si) => (
        <div key={si} style={{ marginBottom: 28 }}>
          <div style={{
            display: "flex",
            alignItems: "center",
            gap: 12,
            marginBottom: 12,
            paddingBottom: 8,
            borderBottom: `2px solid ${TYPE_BADGES[section.type].border}30`,
          }}>
            <h3 style={{
              fontSize: 14,
              fontWeight: 700,
              margin: 0,
              textTransform: "uppercase",
              letterSpacing: "0.05em",
              color: "#e2e8f0",
            }}>
              {section.title}
            </h3>
            <TypeBadge type={section.type} />
            {section.syncable && (
              <span style={{
                fontSize: 10,
                color: "#10b981",
                fontWeight: 600,
                display: "flex",
                alignItems: "center",
                gap: 4,
              }}>
                <span style={{ width: 6, height: 6, borderRadius: "50%", background: "#10b981" }} />
                BigBox Sync Enabled
              </span>
            )}
          </div>

          <div style={{
            fontSize: 11,
            color: "#64748b",
            marginBottom: 10,
            fontStyle: "italic",
          }}>
            {section.typeLabel}
          </div>

          <div style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))",
            gap: 10,
          }}>
            {section.items.map((item, ii) => (
              <PricingItem
                key={ii}
                item={item}
                type={section.type}
                showBreakdown={showBreakdown}
              />
            ))}
          </div>
        </div>
      ))}

      {/* Footer note */}
      <div style={{
        marginTop: 32,
        padding: "16px 20px",
        background: "#0f172a",
        borderRadius: 10,
        border: "1px solid #1e293b",
        fontSize: 12,
        color: "#64748b",
        lineHeight: 1.6,
      }}>
        <strong style={{ color: "#94a3b8" }}>How this works:</strong> Your edits override the platform defaults.
        Items marked <span style={{ color: "#10b981" }}>HD Live</span> sync with Home Depot pricing automatically.
        <span style={{ color: "#06b6d4" }}> INSTALLED</span> prices include materials + labor bundled together.
        <span style={{ color: "#10b981" }}> MATERIAL ONLY</span> prices are just the part — labor is calculated separately.
        <span style={{ color: "#ef4444" }}> MULTIPLIERS</span> adjust the total cost, not a dollar amount (1.0 = no change).
        <span style={{ color: "#f59e0b" }}> LABOR</span> rates are what you charge per hour.
        <span style={{ color: "#8b5cf6" }}> FLAT RATE</span> items are a fixed price regardless of specifics.
      </div>
    </div>
  );
}
