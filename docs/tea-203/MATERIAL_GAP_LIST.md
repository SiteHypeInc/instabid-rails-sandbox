# InstaBid Material Gap List — Items Needing Prices

**Purpose:** These are materials referenced in the Manus Trade Guide that InstaBid does NOT currently have pricing keys for. Once prices are scraped (BigBox Collections, Claude web search, or Jesse's scraper), they get added to `default_pricings` and the pricing dashboard.

**No prices listed intentionally.** Prices come from scraping, not guessing.

**For each item:** suggested pricing_key, type, unit, syncable (can HD provide this?), and notes on material quantity calculation if applicable.

---

## SIDING — 15 missing items

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 1 | Vinyl Trim Coil 24" | siding_vinyl_trim_coil | MATERIAL | roll | YES | |
| 2 | Vinyl F-Channel | siding_f_channel | MATERIAL | 12ft | YES | |
| 3 | Vinyl Starter Strip | siding_starter_strip | MATERIAL | 12ft | YES | Qty = perimeter / 12 |
| 4 | Vinyl Undersill Trim | siding_undersill_trim | MATERIAL | 12ft | YES | |
| 5 | Fiber Cement Shakes | siding_fiber_cement_shake | MATERIAL | sqft | YES | Cedar-look panels |
| 6 | Fiber Cement Trim Boards | siding_fiber_trim | MATERIAL | 12ft | YES | 1x4, 1x6, 1x8 |
| 7 | Fiber Cement Caulk | siding_fiber_caulk | MATERIAL | tube | YES | Color-matched |
| 8 | Stucco Finish Coat | siding_stucco_finish | MATERIAL | bag | YES | Currently lumped into one stucco price |
| 9 | Stucco Mesh/Lath | siding_stucco_mesh | MATERIAL | sqft | YES | Metal reinforcement |
| 10 | Stucco Bonding Agent | siding_stucco_bond | MATERIAL | gallon | YES | |
| 11 | Metal Trim Coil | siding_metal_trim | MATERIAL | roll | YES | Aluminum 24" rolls |
| 12 | Flashing (siding) | siding_flashing | MATERIAL | 10ft | YES | Aluminum or galvanized |
| 13 | Exterior Caulk/Sealant | siding_caulk | MATERIAL | tube | YES | |
| 14 | Vinyl Siding Nails (itemized) | siding_nails | MATERIAL | box | YES | Currently in fastener_kit |
| 15 | Fiber Cement Screws | siding_fiber_screws | MATERIAL | box | YES | Corrosion-resistant |

---

## ROOFING — 6 missing items

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 1 | Slate Roofing | mat_slate | MATERIAL | sqft | PARTIAL | Specialty — may need web search |
| 2 | Synthetic Slate | mat_synthetic_slate | MATERIAL | sqft | YES | DaVinci, CeDUR brands at HD |
| 3 | Roof Sealant/Coating | roof_sealant | MATERIAL | gallon | YES | |
| 4 | Pipe Boot/Jack | pipe_boot | MATERIAL | each | YES | Qty = count of roof penetrations |
| 5 | Step Flashing | step_flashing_lf | MATERIAL | piece | YES | Typically 10-packs |
| 6 | Gutter (linear ft) | gutter_lf | MATERIAL | lf | YES | 5" or 6" K-style |
| 7 | Gutter Downspout | gutter_downspout | MATERIAL | each | YES | 10ft sections |

---

## PLUMBING — 22 missing items

### Pipes (beyond what we have)

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 1 | PEX 1" 100ft | plumb_pex_1in | MATERIAL | roll | YES | Larger main lines |
| 2 | Copper 3/4" 10ft | plumb_copper_3_4 | MATERIAL | each | YES | |
| 3 | CPVC 1/2" 10ft | plumb_cpvc_half | MATERIAL | each | YES | Hot water supply |
| 4 | CPVC 3/4" 10ft | plumb_cpvc_3_4 | MATERIAL | each | YES | |
| 5 | ABS 3" 10ft | plumb_abs_3in | MATERIAL | each | YES | Drain/waste |
| 6 | PVC 3" 10ft | plumb_pvc_3in | MATERIAL | each | YES | Drain |
| 7 | PVC 4" 10ft | plumb_pvc_4in | MATERIAL | each | YES | Main drain |

### Fittings (buy in bags/packs — price per piece or per bag)

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 8 | PEX 90° Elbow 1/2" | plumb_pex_elbow_half | MATERIAL | each | YES | Qty formula: \~1 per 4 LF |
| 9 | PEX Tee 1/2" | plumb_pex_tee_half | MATERIAL | each | YES | Qty: \~1 per fixture |
| 10 | PEX Coupling 1/2" | plumb_pex_coupling_half | MATERIAL | each | YES | |
| 11 | Copper 90° Elbow 1/2" | plumb_copper_elbow_half | MATERIAL | each | YES | |
| 12 | Copper Tee 1/2" | plumb_copper_tee_half | MATERIAL | each | YES | |
| 13 | PVC 90° Elbow 2" | plumb_pvc_elbow_2in | MATERIAL | each | YES | Drain fittings |
| 14 | PVC Tee 2" | plumb_pvc_tee_2in | MATERIAL | each | YES | |
| 15 | Brass Adapter (various) | plumb_brass_adapter | MATERIAL | each | YES | Transition fittings |

### Valves & Stops

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 16 | Ball Valve 1/2" | plumb_ball_valve_half | MATERIAL | each | YES | Main shutoffs |
| 17 | Ball Valve 3/4" | plumb_ball_valve_3_4 | MATERIAL | each | YES | |
| 18 | Angle Stop Valve | plumb_angle_stop | MATERIAL | each | YES | Under-sink shutoff. Qty: 2 per sink |
| 19 | Check Valve | plumb_check_valve | MATERIAL | each | YES | Backflow prevention |
| 20 | Pressure Relief Valve | plumb_prv | MATERIAL | each | YES | Water heater safety |

### Drain/Vent/Rough-in

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 21 | P-Trap 1.5" | plumb_p_trap | MATERIAL | each | YES | Qty: 1 per fixture drain |
| 22 | Wax Ring (toilet) | plumb_wax_ring | MATERIAL | each | YES | Qty: 1 per toilet |

---

## ELECTRICAL — 20 missing items

### Wire & Cable

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 1 | Romex 10/2 250ft | elec_wire_10_2 | MATERIAL | roll | YES | Dryers, water heaters |
| 2 | Romex 10/3 250ft | elec_wire_10_3 | MATERIAL | roll | YES | Ranges, heavy appliances |
| 3 | Romex 6/3 (per ft) | elec_wire_6_3_lf | MATERIAL | lf | YES | Sub panels, heavy loads |
| 4 | THHN Wire 12AWG 500ft | elec_thhn_12 | MATERIAL | roll | YES | Conduit runs |
| 5 | UF-B Cable 12/2 250ft | elec_uf_cable | MATERIAL | roll | YES | Outdoor/underground |

### Conduit

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 6 | EMT Conduit 1/2" 10ft | elec_emt_half | MATERIAL | each | YES | |
| 7 | EMT Conduit 3/4" 10ft | elec_emt_3_4 | MATERIAL | each | YES | |
| 8 | PVC Conduit 1/2" 10ft | elec_pvc_conduit_half | MATERIAL | each | YES | |
| 9 | Flex Conduit 1/2" 25ft | elec_flex_conduit | MATERIAL | roll | YES | |
| 10 | Conduit Fittings (assorted) | elec_conduit_fittings | MATERIAL | kit | YES | Connectors, bushings |

### Boxes

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 11 | Old Work Box 1-gang | elec_box_old_work | MATERIAL | each | YES | Retrofit installs |
| 12 | New Work Box 1-gang | elec_box_new_work | MATERIAL | each | YES | New construction |
| 13 | Junction Box 4x4" | elec_junction_box | MATERIAL | each | YES | |
| 14 | Weatherproof Box | elec_wp_box | MATERIAL | each | YES | Outdoor |

### Outlets & Switches (expanded)

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 15 | 20A Standard Outlet | elec_outlet_20a | MATERIAL | each | YES | |
| 16 | USB Outlet Combo | elec_outlet_usb | MATERIAL | each | YES | |
| 17 | Weatherproof Outlet Cover | elec_outlet_wp_cover | MATERIAL | each | YES | |
| 18 | Smart Switch (WiFi) | elec_smart_switch | MATERIAL | each | YES | |
| 19 | 3-Way Switch | elec_switch_3way | MATERIAL | each | YES | Already in SKUs, needs key |
| 20 | Occupancy Sensor Switch | elec_occupancy_switch | MATERIAL | each | YES | |

---

## HVAC — 15 missing items

### Ductwork (expanded)

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 1 | Flex Duct 6" 25ft | hvac_flex_duct_6 | MATERIAL | each | YES | |
| 2 | Flex Duct 8" 25ft | hvac_flex_duct_8 | MATERIAL | each | YES | |
| 3 | Rigid Sheet Metal Duct | hvac_rigid_duct_lf | MATERIAL | lf | PARTIAL | Often custom fab |
| 4 | Duct Insulation Wrap | hvac_duct_insulation | MATERIAL | roll | YES | |
| 5 | Duct Mastic/Sealant | hvac_duct_mastic | MATERIAL | gallon | YES | |
| 6 | Duct Tape (HVAC rated) | hvac_duct_tape | MATERIAL | roll | YES | |
| 7 | Duct Hangers/Supports | hvac_duct_hangers | MATERIAL | box | YES | |

### Components

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 8 | Copper Line Set 25ft | hvac_line_set | MATERIAL | each | YES | 1/4" + 3/8" insulated |
| 9 | Condensate Pump | hvac_condensate_pump | MATERIAL | each | YES | |
| 10 | Disconnect Box 60A | hvac_disconnect | MATERIAL | each | YES | Required by code |
| 11 | AC Pad/Stand | hvac_pad | MATERIAL | each | YES | Condenser unit base |
| 12 | Thermostat Wire 18/5 250ft | hvac_thermostat_wire | MATERIAL | roll | YES | |

### Ventilation (new subcategory)

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 13 | Bath Exhaust Fan | hvac_bath_fan | INSTALLED | each | YES | Includes install labor |
| 14 | Range Hood | hvac_range_hood | INSTALLED | each | YES | Includes install labor |
| 15 | Dryer Vent Kit | hvac_dryer_vent | MATERIAL | kit | YES | |

---

## PAINTING — 8 missing items

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 1 | Deck Stain (per sqft) | paint_deck_stain_mat | MATERIAL | sqft | YES | Semi-transparent/solid |
| 2 | Deck Stain Labor | paint_deck_stain_labor | LABOR_PER_UNIT | sqft | NO | |
| 3 | Epoxy Floor Coating | paint_epoxy_mat | MATERIAL | gallon | YES | Garage floors |
| 4 | Epoxy Floor Labor | paint_epoxy_labor | LABOR_PER_UNIT | sqft | NO | |
| 5 | Cabinet Refinishing (per door) | paint_cabinet_door | INSTALLED | each | NO | Includes strip/prime/paint |
| 6 | Wallpaper Removal | paint_wallpaper_removal | LABOR_PER_UNIT | sqft | NO | Labor only |
| 7 | Elastomeric Coating | paint_elastomeric_mat | MATERIAL | gallon | YES | Crack-resistant exterior |
| 8 | Shellac Primer | paint_shellac_primer | MATERIAL | gallon | YES | Stain/odor blocking |

---

## DRYWALL — 12 missing items

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 1 | Moisture-Resistant Board (green) | drywall_sheet_moisture | MATERIAL | sheet | YES | Bathrooms |
| 2 | Fire-Rated Board (Type X) | drywall_sheet_fire | MATERIAL | sheet | YES | Garages, ceilings |
| 3 | Mold-Resistant Board (purple) | drywall_sheet_mold | MATERIAL | sheet | YES | Basements |
| 4 | Setting Compound (hot mud) | drywall_setting_compound | MATERIAL | bag | YES | Quick-set |
| 5 | Mesh Tape | drywall_mesh_tape | MATERIAL | roll | YES | Self-adhesive |
| 6 | Bullnose Corner Bead | drywall_bullnose_bead | MATERIAL | each | YES | Rounded corners |
| 7 | L-Bead | drywall_l_bead | MATERIAL | each | YES | Edge trim |
| 8 | Skip Trowel Texture | drywall_texture_skip_trowel | LABOR_PER_UNIT | sqft | NO | Labor only |
| 9 | Skim Coat (smooth) | drywall_skim_coat | LABOR_PER_UNIT | sqft | NO | Level 5 prep |
| 10 | Soundproof Drywall | drywall_sheet_sound | MATERIAL | sheet | YES | QuietRock etc |
| 11 | Resilient Channel | drywall_resilient_channel | MATERIAL | 12ft | YES | Sound isolation |
| 12 | Batt Insulation R-13 | insulation_batt_r13 | MATERIAL | sqft | YES | While walls are open |

---

## FLOORING — 15 missing items

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 1 | Sheet Vinyl | floor_sheet_vinyl | MATERIAL | sqft | YES | |
| 2 | VCT (Vinyl Composition Tile) | floor_vct | MATERIAL | sqft | YES | Commercial/laundry |
| 3 | Bamboo | floor_bamboo | MATERIAL | sqft | YES | |
| 4 | Natural Stone (marble) | floor_marble | MATERIAL | sqft | PARTIAL | Specialty — web search |
| 5 | Natural Stone (travertine) | floor_travertine | MATERIAL | sqft | PARTIAL | Specialty |
| 6 | Large Format Tile 24x24 | floor_tile_large | MATERIAL | sqft | YES | |
| 7 | Mosaic Tile | floor_mosaic | MATERIAL | sqft | YES | |
| 8 | Thinset Mortar | floor_thinset | MATERIAL | bag | YES | 50lb bag, covers \~75 sqft |
| 9 | Grout (sanded) | floor_grout_sanded | MATERIAL | bag | YES | 25lb bag |
| 10 | Grout (unsanded) | floor_grout_unsanded | MATERIAL | bag | YES | 10lb bag |
| 11 | Tile Sealer | floor_tile_sealer | MATERIAL | gallon | YES | Natural stone |
| 12 | T-Molding Transition | floor_transition_t | MATERIAL | each | YES | 6ft pieces |
| 13 | Reducer Transition | floor_transition_reducer | MATERIAL | each | YES | |
| 14 | Self-Leveling Compound | floor_self_level | MATERIAL | bag | YES | 50lb bag |
| 15 | Moisture Barrier | floor_moisture_barrier | MATERIAL | sqft | YES | Poly sheeting |

---

## 🆕 CABINETS & COUNTERTOPS — 33 new items (entire new trade)

### Cabinets

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 1 | Stock Base Cabinet 30" | cab_base_30_stock | INSTALLED | each | YES | HD sells stock |
| 2 | Stock Wall Cabinet 30" | cab_wall_30_stock | INSTALLED | each | YES | |
| 3 | Stock Tall/Pantry 84" | cab_tall_stock | INSTALLED | each | YES | |
| 4 | Semi-Custom Base 30" | cab_base_30_semi | INSTALLED | each | PARTIAL | KraftMaid at HD |
| 5 | Semi-Custom Wall 30" | cab_wall_30_semi | INSTALLED | each | PARTIAL | |
| 6 | Custom Base (per LF) | cab_base_custom_lf | INSTALLED | lf | NO | Specialty — web search range |
| 7 | Custom Wall (per LF) | cab_wall_custom_lf | INSTALLED | lf | NO | Specialty — web search range |
| 8 | Cabinet Hardware (pulls) | cab_hardware_pull | MATERIAL | each | YES | |
| 9 | Cabinet Hardware (knobs) | cab_hardware_knob | MATERIAL | each | YES | |
| 10 | Soft-Close Hinges | cab_hinge_soft_close | MATERIAL | each | YES | |
| 11 | Soft-Close Drawer Slides | cab_drawer_slide | MATERIAL | pair | YES | |
| 12 | Lazy Susan | cab_lazy_susan | INSTALLED | each | YES | |
| 13 | Pull-Out Shelf | cab_pullout_shelf | INSTALLED | each | YES | |
| 14 | Cabinet Crown Molding | cab_crown_lf | MATERIAL | lf | YES | |
| 15 | Filler Strip | cab_filler | MATERIAL | each | YES | |
| 16 | End Panel | cab_end_panel | MATERIAL | each | YES | |
| 17 | Cabinet Refacing (per LF) | cab_reface_lf | INSTALLED | lf | NO | Specialty |
| 18 | Cabinet Painting (per door) | cab_paint_door | INSTALLED | each | NO | Overlaps painting trade |

### Countertops

| # | Item | Pricing Key | Type | Unit | Syncable? | Notes |
|---|------|------------|------|------|-----------|-------|
| 19 | Laminate Countertop | counter_laminate_sqft | MATERIAL | sqft | YES | HD stocks |
| 20 | Butcher Block | counter_butcher_sqft | MATERIAL | sqft | YES | HD stocks |
| 21 | Solid Surface (Corian) | counter_solid_surface_sqft | MATERIAL | sqft | PARTIAL | HD special order |
| 22 | Quartz | counter_quartz_sqft | MATERIAL | sqft | PARTIAL | Specialty — web search |
| 23 | Granite | counter_granite_sqft | MATERIAL | sqft | NO | Stone yards — web search range |
| 24 | Marble | counter_marble_sqft | MATERIAL | sqft | NO | Stone yards — web search range |
| 25 | Concrete Countertop | counter_concrete_sqft | MATERIAL | sqft | NO | Custom — web search range |
| 26 | Counter Install Labor | counter_install_sqft | LABOR_PER_UNIT | sqft | NO | |
| 27 | Edge Profile (basic) | counter_edge_basic_lf | INSTALLED | lf | NO | Ogee, beveled |
| 28 | Edge Profile (premium) | counter_edge_premium_lf | INSTALLED | lf | NO | Waterfall, mitered |
| 29 | Backsplash Subway Tile | backsplash_subway_sqft | MATERIAL | sqft | YES | |
| 30 | Backsplash Mosaic Tile | backsplash_mosaic_sqft | MATERIAL | sqft | YES | |
| 31 | Backsplash Install Labor | backsplash_install_sqft | LABOR_PER_UNIT | sqft | NO | |
| 32 | Sink Cutout | counter_sink_cutout | LUMP_SUM | each | NO | Template + cut |
| 33 | Cooktop Cutout | counter_cooktop_cutout | LUMP_SUM | each | NO | |

---

## SUMMARY

| Trade | Missing Items | Syncable (HD scrapable) | Manual/Web Search |
|-------|--------------|------------------------|-------------------|
| Siding | 15 | 15 | 0 |
| Roofing | 7 | 6 | 1 (slate) |
| Plumbing | 22 | 22 | 0 |
| Electrical | 20 | 20 | 0 |
| HVAC | 15 | 14 | 1 (rigid duct) |
| Painting | 8 | 4 | 4 (labor items) |
| Drywall | 12 | 10 | 2 (labor items) |
| Flooring | 15 | 13 | 2 (stone) |
| Cabinets & Countertops | 33 | 15 | 18 (custom/specialty) |
| **TOTAL** | **147** | **119** | **28** |

**119 items can be scraped from Home Depot.** That's one BigBox Collection or one Jesse scraper run away from having prices.

**28 items need Claude web search** for price ranges (granite, marble, custom cabinetry, labor rates). Those are Tier 3B candidates.

---

## NEXT STEPS

1\. **Todd/Jesse:** Add the 119 HD-scrapable items to the BigBox Collection (or Jesse's scraper target list). Run the scrape. Prices populate material_prices automatically.

2\. **Claude web search (or Tavily+Haiku):** Run the 28 specialty items through Tier 3B. Write ranges to material_prices with confidence=medium.

3\. **Todd:** Add all 147 new keys to pricing_key_reference.yml and material_price_mappings.yml with correct types and syncable flags.

4\. **Jesse:** Write the Cabinets & Countertops estimator method + material list generator. Use kitchen remodel doc (from John) for the quantity formulas.

5\. **John:** Review the populated dashboard. Adjust any prices that look wrong. Provide material quantity formulas for fittings (bags of elbows per LF of repipe, etc.) from contractor experience.

---

## MATERIAL QUANTITY FORMULAS (from existing Node code — preserve these)

These formulas are already in `materialListGenerator.js` and MUST be carried over to Rails:

**Roofing:**

- Shingle bundles = (sqft / 100) × 3 × 1.10 waste

- Underlayment rolls = sqft / 400

- Drip edge = perimeter (√sqft × 4)

- Ridge cap = √sqft / 2

- Nails = sqft / 1000 (boxes)

**Drywall:**

- Sheets = sqft / 32

- Joint compound = sqft × 0.35 (coverage factor)

- Tape = sqft × 0.15

- Screws = sheets × 0.50

**Siding:**

- House wrap rolls = sqft / 900

- J-channel = perimeter + window/door perimeter

**Plumbing (NEW — John to validate):**

- PEX per fixture: \~20 LF hot + 20 LF cold per fixture (rough estimate)

- Elbows: \~1 per 4 LF of pipe run

- Tees: \~1 per fixture branch

- Angle stops: 2 per sink, 1 per toilet

- P-traps: 1 per fixture drain

- Wax rings: 1 per toilet

- Full repipe estimate: \~1.5 LF pipe per sqft of house

**Electrical (NEW — John to validate):**

- Wire per circuit: \~50 LF average

- Boxes: 1 per outlet + 1 per switch + 1 per junction

- Breakers: 1 per circuit

---

**Gap list generated from Manus Trade Materials Reference Guide vs. SiteHypeInc/instabid2 codebase**

**April 21, 2026**