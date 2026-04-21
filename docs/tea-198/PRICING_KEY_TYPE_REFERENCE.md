# InstaBid Pricing Key Type Reference

**What this is:** Every pricing key in the system, what type of value it holds, and whether BigBox sync should touch it. Pin this next to the migration spec. If a key says "DO NOT SYNC" — BigBox never writes to it. If it says "SYNC + LABOR_ADDER" — BigBox writes material cost, we add a flat labor component to get the installed price.

---

## Value Types Explained

| Type | What It Means | Example | BigBox Syncable? |
|------|-------------|---------|-----------------|
| **MATERIAL** | Raw material cost per unit. No labor included. | Drywall sheet = $12/sheet | YES — direct write |
| **INSTALLED** | Material + labor bundled into one price. What a contractor charges the customer for the complete job. | Toilet Install = $375 | YES — but BigBox gives material only, must add labor_adder |
| **EQUIPMENT** | Full unit cost (HVAC systems, panels). Includes the equipment, not the install labor. | Furnace Standard = $3500 | YES — direct write |
| **LABOR_RATE** | Dollars per hour or per unit of work. Set by contractor or BLS data. | Plumbing Labor = $95/hr | NO — comes from BLS or contractor override |
| **LABOR_PER_UNIT** | Labor cost per sqft or per unit of area. Used in area-based calculations. | Drywall Hang = $0.75/sqft | NO — manual/contractor set |
| **MULTIPLIER** | Decimal factor applied to costs. Not a dollar amount. | Pitch 6/12 = 1.1 | NO — business rule |
| **LUMP_SUM** | Flat rate for a category of work. Not tied to quantity. | Drywall Repair Minor = $175 | NO — manual/contractor set |
| **DISPOSAL** | Cost per sqft for removal/disposal. | Asphalt Disposal = $0.40/sqft | PARTIAL — regional, rarely changes |
| **PERMIT** | Flat fee for permits. | Electrical Permit = $200 | NO — regional/municipal |

---

## ROOFING (23 keys)

| Pricing Key | Current Value | Type | BigBox Sync? | Notes |
|------------|--------------|------|-------------|-------|
| pitch_3_12 | 1.0 | MULTIPLIER | NO | |
| pitch_4_12 | 1.0 | MULTIPLIER | NO | |
| pitch_5_12 | 1.05 | MULTIPLIER | NO | |
| pitch_6_12 | 1.1 | MULTIPLIER | NO | |
| pitch_7_12 | 1.15 | MULTIPLIER | NO | |
| pitch_8_12 | 1.2 | MULTIPLIER | NO | |
| pitch_9_12 | 1.3 | MULTIPLIER | NO | |
| pitch_10_12 | 1.4 | MULTIPLIER | NO | |
| pitch_11_12 | 1.5 | MULTIPLIER | NO | |
| pitch_12_12 | 1.6 | MULTIPLIER | NO | |
| mat_asphalt | $40.00/bundle | MATERIAL | YES | 3-tab shingles |
| mat_arch | $44.96/bundle | MATERIAL | YES | Architectural shingles |
| mat_metal | $9.50/sqft | MATERIAL | YES | Metal roofing panels |
| mat_tile | $12.00/sqft | MATERIAL | YES | Concrete/clay tile |
| mat_wood_shake | $14.00/sqft | MATERIAL | YES | Wood shake |
| underlayment_roll | $45.00/roll | MATERIAL | YES | Synthetic underlayment |
| nails_box | $85.00/box | MATERIAL | YES | Roofing nails |
| starter_lf | $2.50/lf | MATERIAL | YES | Starter strip |
| ridge_lf | $3.00/lf | MATERIAL | YES | Ridge cap shingles |
| drip_edge_lf | $2.75/lf | MATERIAL | YES | Drip edge flashing |
| ice_shield_lf | $4.50/lf | MATERIAL | YES | Ice & water shield |
| vent_unit | $25.00/each | MATERIAL | YES | Box vents |
| ridge_vent_lf | $5.50/lf | MATERIAL | YES | Ridge vent |
| osb_sheet | $28.00/sheet | MATERIAL | YES | OSB sheathing 4x8 |
| disposal_asphalt_sqft | $0.40/sqft | DISPOSAL | PARTIAL | Tear-off disposal |
| disposal_wood_sqft | $0.40/sqft | DISPOSAL | PARTIAL | |
| disposal_metal_sqft | $0.50/sqft | DISPOSAL | PARTIAL | |
| disposal_tile_sqft | $0.75/sqft | DISPOSAL | PARTIAL | |
| chimney_flash | $125.00/kit | MATERIAL | YES | Chimney flashing kit |
| skylight_flash | $85.00/kit | MATERIAL | YES | Skylight flashing kit |
| valley_lf | $6.00/lf | MATERIAL | YES | Valley flashing |
| labor_rate_sqft | $0.04 | LABOR_PER_UNIT | NO | Base labor hours per sqft |
| chimney_labor_hrs | 3 hrs | LABOR_PER_UNIT | NO | Hours per chimney |
| skylight_labor_hrs | 2 hrs | LABOR_PER_UNIT | NO | Hours per skylight |

---

## SIDING (22 keys)

| Pricing Key | Current Value | Type | BigBox Sync? | Notes |
|------------|--------------|------|-------------|-------|
| siding_vinyl | $5.50/sqft | MATERIAL | YES | Vinyl siding panels |
| siding_fiber_cement | $9.50/sqft | MATERIAL | YES | HardiePlank etc |
| siding_wood | $14.00/sqft | MATERIAL | YES | Cedar/wood siding |
| siding_metal | $8.00/sqft | MATERIAL | YES | Steel/aluminum panels |
| siding_stucco | $11.00/sqft | MATERIAL | YES | Stucco materials |
| siding_labor_vinyl | $3.50/sqft | LABOR_PER_UNIT | NO | Install labor per sqft |
| siding_labor_fiber | $5.50/sqft | LABOR_PER_UNIT | NO | |
| siding_labor_wood | $6.50/sqft | LABOR_PER_UNIT | NO | |
| siding_labor_metal | $4.50/sqft | LABOR_PER_UNIT | NO | |
| siding_labor_stucco | $7.50/sqft | LABOR_PER_UNIT | NO | |
| siding_labor_rate | $45/hr | LABOR_RATE | NO | Hourly rate |
| siding_housewrap_roll | $175/roll | MATERIAL | YES | House wrap 9x100 |
| siding_j_channel | $12/12ft | MATERIAL | YES | J-channel trim |
| siding_corner_post | $35/each | MATERIAL | YES | Corner posts |
| siding_window_trim | $55/each | MATERIAL | YES | Window trim coil |
| siding_door_trim | $75/each | MATERIAL | YES | Door trim coil |
| siding_soffit_sqft | $8/sqft | MATERIAL | YES | Soffit panels |
| siding_fascia_lf | $6/lf | MATERIAL | YES | Fascia board |
| siding_fastener_kit | $175/kit | MATERIAL | YES | Fastener package |
| siding_removal_sqft | $1.75/sqft | DISPOSAL | PARTIAL | Old siding removal |
| siding_story_2 | 1.25 | MULTIPLIER | NO | 2-story adjustment |
| siding_story_3 | 1.50 | MULTIPLIER | NO | 3-story adjustment |

---

## ELECTRICAL (17 keys)

| Pricing Key | Current Value | Type | BigBox Sync? | Notes |
|------------|--------------|------|-------------|-------|
| elec_wire_lf | $1.00/lf | MATERIAL | YES | Romex wire per foot |
| elec_panel_100 | $450 | INSTALLED | SYNC + LABOR_ADDER | 100A sub panel installed |
| elec_panel_200 | $550 | INSTALLED | SYNC + LABOR_ADDER | 200A main panel installed |
| elec_panel_400 | $1200 | INSTALLED | SYNC + LABOR_ADDER | 400A panel installed |
| elec_rewire_sqft | $11.50/sqft | INSTALLED | NO | Full rewire — too variable |
| elec_ceiling_fan_install | $200 | INSTALLED | SYNC + LABOR_ADDER | Fan + install |
| elec_outlet | $12 | MATERIAL | YES | Duplex outlet unit cost |
| elec_outlet_gfci | $35 | MATERIAL | YES | GFCI outlet unit cost |
| elec_switch | $10 | MATERIAL | YES | Single pole switch |
| elec_switch_dimmer | $50 | MATERIAL | YES | Dimmer switch |
| elec_light_install | $35 | INSTALLED | SYNC + LABOR_ADDER | Light fixture installed |
| elec_recessed | $55 | INSTALLED | SYNC + LABOR_ADDER | Recessed light installed |
| elec_circuit_20a | $95 | INSTALLED | NO | Circuit install — labor-heavy |
| elec_circuit_30a | $130 | INSTALLED | NO | |
| elec_circuit_50a | $185 | INSTALLED | NO | |
| elec_ev_charger | $350 | INSTALLED | SYNC + LABOR_ADDER | EV charger installed |
| elec_permit | $200 | PERMIT | NO | Permit fee |

---

## PLUMBING (28 keys)

| Pricing Key | Current Value | Type | BigBox Sync? | Notes |
|------------|--------------|------|-------------|-------|
| plumb_labor_rate | $95/hr | LABOR_RATE | NO | Standard hourly |
| plumb_labor_emergency | $175/hr | LABOR_RATE | NO | Emergency rate |
| plumb_service_call | $95 | LUMP_SUM | NO | Service call fee |
| plumb_toilet | $375 | INSTALLED | SYNC + LABOR_ADDER | Toilet + install |
| plumb_sink_bath | $350 | INSTALLED | SYNC + LABOR_ADDER | Bath sink + install |
| plumb_sink_kitchen | $550 | INSTALLED | SYNC + LABOR_ADDER | Kitchen sink + install |
| plumb_faucet_bath | $225 | INSTALLED | SYNC + LABOR_ADDER | Bath faucet + install |
| plumb_faucet_kitchen | $300 | INSTALLED | SYNC + LABOR_ADDER | Kitchen faucet + install |
| plumb_shower_valve | $450 | INSTALLED | SYNC + LABOR_ADDER | Shower valve + install |
| plumb_tub | $1200 | INSTALLED | SYNC + LABOR_ADDER | Tub + install |
| plumb_dishwasher | $200 | INSTALLED | SYNC + LABOR_ADDER | Dishwasher hookup |
| plumb_garbage_disposal | $325 | INSTALLED | SYNC + LABOR_ADDER | Disposal + install |
| plumb_ice_maker | $150 | INSTALLED | SYNC + LABOR_ADDER | Ice maker line |
| plumb_heater_tank_40 | $1200 | INSTALLED | SYNC + LABOR_ADDER | 40 gal tank installed |
| plumb_heater_tank_50 | $1600 | INSTALLED | SYNC + LABOR_ADDER | 50 gal tank installed |
| plumb_heater_tankless_gas | $3500 | INSTALLED | SYNC + LABOR_ADDER | Tankless gas installed |
| plumb_heater_tankless_elec | $2200 | INSTALLED | SYNC + LABOR_ADDER | Tankless electric installed |
| plumb_water_softener | $1800 | INSTALLED | SYNC + LABOR_ADDER | Softener installed |
| plumb_sump_pump | $650 | INSTALLED | SYNC + LABOR_ADDER | Sump pump installed |
| plumb_repipe_pex_lf | $2.50/lf | MATERIAL | YES | PEX pipe per foot |
| plumb_repipe_copper_lf | $4.50/lf | MATERIAL | YES | Copper pipe per foot |
| plumb_main_line | $1200 | LUMP_SUM | NO | Main line replacement |
| plumb_gas_line_new | $500 | LUMP_SUM | NO | New gas line |
| plumb_access_basement | 1.0 | MULTIPLIER | NO | Easy access |
| plumb_access_crawlspace | 1.15 | MULTIPLIER | NO | Moderate access |
| plumb_access_slab | 1.35 | MULTIPLIER | NO | Hard access |
| plumb_location_garage | 1.0 | MULTIPLIER | NO | |
| plumb_location_basement | 1.0 | MULTIPLIER | NO | |
| plumb_location_closet | 1.1 | MULTIPLIER | NO | |
| plumb_location_attic | 1.25 | MULTIPLIER | NO | |

---

## HVAC (23 keys)

| Pricing Key | Current Value | Type | BigBox Sync? | Notes |
|------------|--------------|------|-------------|-------|
| hvac_furnace_standard | $3500 | EQUIPMENT | YES | 80% furnace unit |
| hvac_furnace_high | $4500 | EQUIPMENT | YES | 95% furnace unit |
| hvac_ac_standard | $4000 | EQUIPMENT | YES | 14 SEER AC unit |
| hvac_ac_high | $5500 | EQUIPMENT | YES | 18 SEER AC unit |
| hvac_heatpump_standard | $5500 | EQUIPMENT | YES | 14 SEER heat pump |
| hvac_heatpump_high | $7500 | EQUIPMENT | YES | 18 SEER heat pump |
| hvac_minisplit | $2500 | EQUIPMENT | YES | Mini split unit |
| hvac_duct_new | $15/lf | MATERIAL | YES | New ductwork |
| hvac_duct_repair | $8/lf | MATERIAL | YES | Duct repair |
| hvac_thermostat | $350 | EQUIPMENT | YES | Thermostat unit |
| hvac_refrigerant | $250 | MATERIAL | YES | Refrigerant charge |
| hvac_filters | $200 | MATERIAL | YES | Filter set |
| hvac_labor_rate | $85/hr | LABOR_RATE | NO | HVAC hourly |
| hvac_labor_furnace | 12 hrs | LABOR_PER_UNIT | NO | Install hours |
| hvac_labor_ac | 10 hrs | LABOR_PER_UNIT | NO | |
| hvac_labor_heatpump | 14 hrs | LABOR_PER_UNIT | NO | |
| hvac_labor_minisplit | 8 hrs | LABOR_PER_UNIT | NO | |
| hvac_size_small | 0.9 | MULTIPLIER | NO | <1500 sqft |
| hvac_size_med | 1.0 | MULTIPLIER | NO | 1500-2500 sqft |
| hvac_size_large | 1.2 | MULTIPLIER | NO | 2500-3500 sqft |
| hvac_size_xlarge | 1.4 | MULTIPLIER | NO | >3500 sqft |
| hvac_story_2 | 1.2 | MULTIPLIER | NO | |
| hvac_story_3 | 1.4 | MULTIPLIER | NO | |

---

## PAINTING (22 keys)

| Pricing Key | Current Value | Type | BigBox Sync? | Notes |
|------------|--------------|------|-------------|-------|
| paint_exterior_mat | $0.45/sqft | MATERIAL | YES | Exterior paint material |
| paint_exterior_labor | $2.50/sqft | LABOR_PER_UNIT | NO | Exterior labor |
| paint_interior_mat | $0.45/sqft | MATERIAL | YES | Interior paint material |
| paint_interior_labor | $3.50/sqft | LABOR_PER_UNIT | NO | Interior labor |
| paint_ceiling_mat | $0.35/sqft | MATERIAL | YES | Ceiling paint material |
| paint_ceiling_labor | $1.25/sqft | LABOR_PER_UNIT | NO | |
| paint_trim_mat | $0.50/lf | MATERIAL | YES | Trim paint material |
| paint_trim_labor | $2.00/lf | LABOR_PER_UNIT | NO | |
| paint_door_mat | $15/each | MATERIAL | YES | Per door material |
| paint_door_labor | $60/each | LABOR_PER_UNIT | NO | Per door labor |
| paint_window_mat | $10/each | MATERIAL | YES | Per window material |
| paint_window_labor | $40/each | LABOR_PER_UNIT | NO | |
| paint_power_wash_mat | $0.10/sqft | MATERIAL | PARTIAL | |
| paint_power_wash_labor | $0.15/sqft | LABOR_PER_UNIT | NO | |
| paint_patch_minor_mat | $50 | LUMP_SUM | NO | |
| paint_patch_minor_labor | $100 | LUMP_SUM | NO | |
| paint_patch_moderate_mat | $100 | LUMP_SUM | NO | |
| paint_patch_moderate_labor | $250 | LUMP_SUM | NO | |
| paint_patch_extensive_mat | $250 | LUMP_SUM | NO | |
| paint_patch_extensive_labor | $500 | LUMP_SUM | NO | |
| paint_primer_mat | $0.20/sqft | MATERIAL | YES | Primer material |
| paint_primer_labor | $0.30/sqft | LABOR_PER_UNIT | NO | |
| paint_lead_mat | $150 | LUMP_SUM | NO | Lead abatement materials |
| paint_lead_labor | $350 | LUMP_SUM | NO | Lead abatement labor |

---

## DRYWALL (21 keys)

| Pricing Key | Current Value | Type | BigBox Sync? | Notes |
|------------|--------------|------|-------------|-------|
| drywall_labor_rate | $55/hr | LABOR_RATE | NO | Drywall hourly |
| drywall_hang_sqft | $0.75/sqft | LABOR_PER_UNIT | NO | Hang labor |
| drywall_tape_sqft | $0.65/sqft | LABOR_PER_UNIT | NO | Tape labor |
| drywall_sand_sqft | $0.35/sqft | LABOR_PER_UNIT | NO | Sand labor |
| drywall_sheet_half | $12.00/sheet | MATERIAL | YES | 1/2" drywall 4x8 |
| drywall_sheet_5_8 | $18.00/sheet | MATERIAL | YES | 5/8" drywall 4x8 |
| drywall_joint_compound | $18.00/bucket | MATERIAL | YES | 4.5 gal bucket |
| drywall_tape | $8.00/roll | MATERIAL | YES | 300ft roll |
| drywall_screws | $12.00/box | MATERIAL | YES | 5lb box |
| drywall_corner_bead | $5.00/each | MATERIAL | YES | 8ft corner bead |
| drywall_finish_level_3 | 1.0 | MULTIPLIER | NO | Standard finish |
| drywall_finish_level_4 | 1.25 | MULTIPLIER | NO | Smooth finish |
| drywall_finish_level_5 | 1.5 | MULTIPLIER | NO | Glass-smooth |
| drywall_texture_none | 0 | MULTIPLIER | NO | No texture |
| drywall_texture_orange_peel | $0.80/sqft | LABOR_PER_UNIT | NO | Texture application |
| drywall_texture_knockdown | $1.00/sqft | LABOR_PER_UNIT | NO | |
| drywall_texture_popcorn | $0.65/sqft | LABOR_PER_UNIT | NO | |
| drywall_ceiling_10ft | 1.15 | MULTIPLIER | NO | 10ft ceiling adj |
| drywall_ceiling_12ft | 1.3 | MULTIPLIER | NO | 12ft ceiling adj |
| drywall_repair_minor | $175 | LUMP_SUM | NO | Small patch job |
| drywall_repair_moderate | $400 | LUMP_SUM | NO | Medium repair |
| drywall_repair_extensive | $900 | LUMP_SUM | NO | Major repair |

---

## FLOORING (18 keys)

| Pricing Key | Current Value | Type | BigBox Sync? | Notes |
|------------|--------------|------|-------------|-------|
| floor_carpet | $5.00/sqft | MATERIAL | YES | Builder grade carpet |
| floor_vinyl | $3.50/sqft | MATERIAL | YES | Basic vinyl plank |
| floor_laminate | $4.00/sqft | MATERIAL | YES | AC3 laminate |
| floor_lvp | $4.50/sqft | MATERIAL | YES | Luxury vinyl plank |
| floor_hardwood_eng | $10.00/sqft | MATERIAL | YES | Engineered hardwood |
| floor_hardwood_solid | $14.00/sqft | MATERIAL | YES | Solid hardwood |
| floor_tile_ceramic | $7.50/sqft | MATERIAL | YES | 12x12 ceramic |
| floor_tile_porcelain | $10.00/sqft | MATERIAL | YES | 18x18 porcelain |
| floor_labor_carpet | $2.00/sqft | LABOR_PER_UNIT | NO | Carpet install labor |
| floor_labor_vinyl | $2.50/sqft | LABOR_PER_UNIT | NO | Vinyl install labor |
| floor_labor_hardwood | $5.00/sqft | LABOR_PER_UNIT | NO | Hardwood install labor |
| floor_labor_tile | $6.50/sqft | LABOR_PER_UNIT | NO | Tile install labor |
| floor_subfloor | $4.00/sqft | MATERIAL | YES | Subfloor repair |
| floor_removal | $2.00/sqft | DISPOSAL | PARTIAL | Old floor removal |
| floor_underlay | $0.50/sqft | MATERIAL | YES | Underlayment |
| floor_baseboard | $5.00/each | MATERIAL | YES | 8ft baseboard |
| floor_standard | 1.0 | MULTIPLIER | NO | Simple layout |
| floor_moderate | 1.2 | MULTIPLIER | NO | Some cuts/patterns |
| floor_complex | 1.4 | MULTIPLIER | NO | Heavy cuts/borders |

---

## Summary: What BigBox Sync Touches vs. Doesn't

| Category | Count | BigBox Sync? |
|----------|-------|-------------|
| MATERIAL (raw material cost) | ~55 keys | YES — direct write |
| INSTALLED (material + labor) | ~25 keys | YES — with labor_adder |
| EQUIPMENT (full units) | ~10 keys | YES — direct write |
| LABOR_RATE ($/hr) | ~8 keys | NO — BLS or contractor |
| LABOR_PER_UNIT ($/sqft) | ~20 keys | NO — manual |
| MULTIPLIER (decimal) | ~18 keys | NO — business rules |
| LUMP_SUM (flat rate) | ~10 keys | NO — manual |
| DISPOSAL ($/sqft) | ~6 keys | PARTIAL |
| PERMIT (flat fee) | ~1 key | NO — municipal |

**~90 keys are BigBox-syncable. ~60 keys are manual/BLS/business rules.**

The sync pipeline only writes to the ~90. The other ~60 are untouchable. The guardrail (50%/200% bounds) provides a safety net even on the syncable keys.

---

*This is the Rosetta Stone. Every key, every type, every sync rule. If this doc says NO, BigBox doesn't touch it. If it says SYNC + LABOR_ADDER, the formula is: BigBox material price + labor_adder = value written to default_pricings. Pin this next to the migration spec.*

*April 19, 2026*
