#!/usr/bin/env python3
"""
TEA-203 — Road B pipeline: Tavily search + Haiku extract for gap-list items.

Pipeline per item:
  1. Tavily search with `site:homedepot.com <item_name>` (include_raw_content=true).
  2. Pick top HD product URL from results (filter /p/ or /pep/ paths).
  3. Pass the page content to Haiku via OpenRouter with a strict JSON schema.
  4. Haiku returns {title, item_id, price, confidence, reason} — or NULL on ambiguity.
  5. Write a `needs_review_<trade>.json` row per item (same gate pattern as the
     BigBox cabinets review). Johnny eyeballs → bake into material_skus.json →
     populate material_prices with source='web_search'.

Inputs : docs/tea-203/gap_list_parsed.json
         optional --pricing-keys filter (comma-separated) to scope a run
         optional --trade filter (trade key from parsed JSON)
Outputs: docs/tea-203/needs_review_<trade>.json

Env    : TAVILY_API_KEY      (required)
         OPENROUTER_API_KEY  (required; or ANTHROPIC_API_KEY fallback path TBD)

Usage:
  python3 scripts/tea203_road_b.py --trade cabinets_and_countertops \\
    --pricing-keys cab_wall_30_stock,cab_tall_stock,counter_quartz_sqft
"""
import argparse, json, os, sys, time, urllib.parse, urllib.request, urllib.error, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAP  = os.path.join(ROOT, 'docs/tea-203/gap_list_parsed.json')

TAVILY_KEY     = os.environ.get('TAVILY_API_KEY', '').strip()
OPENROUTER_KEY = os.environ.get('OPENROUTER_API_KEY', '').strip()
OPENROUTER_MODEL = os.environ.get('TEA203_MODEL', 'anthropic/claude-haiku-4-5')

TAVILY_URL     = 'https://api.tavily.com/search'
OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions'

HD_URL_RX = re.compile(r'homedepot\.com/p/[^/]+/(\d+)')  # item_id is the trailing digits

# Per-pricing_key query phrasing. Tavily picks /p/ product pages only when the
# query reads like a shopper's search (brand + dimensions + keyword), not
# `site:homedepot.com <label>`. Falls back to item_name if key absent.
QUERY_OVERRIDES = {
    'cab_base_30_stock':         'homedepot.com hampton bay base cabinet 30 inch',
    'cab_wall_30_stock':         'homedepot.com hampton bay wall cabinet 30 inch',
    'cab_tall_stock':            'homedepot.com hampton bay pantry cabinet 84',
    'cab_base_30_semi':          'homedepot.com kraftmaid base cabinet 30 inch',
    'cab_wall_30_semi':          'homedepot.com kraftmaid wall cabinet 30 inch',
    'cab_hinge_soft_close':      'homedepot.com soft close cabinet hinge 35mm',
    'cab_lazy_susan':            'homedepot.com lazy susan cabinet kidney',
    'counter_solid_surface_sqft':'homedepot.com corian solid surface countertop',
    'counter_quartz_sqft':       'homedepot.com quartz countertop slab',
    # Electrical
    'elec_wire_10_2':            'homedepot.com southwire 250 ft 10-2 romex simpull nm-b cable',
    'elec_wire_10_3':            'homedepot.com romex 10/3 250 ft nm-b cable',
    'elec_wire_6_3_lf':          'homedepot.com romex 6/3 nm-b cable per foot',
    'elec_thhn_12':              'homedepot.com thhn 12 awg 500 ft wire',
    'elec_uf_cable':             'homedepot.com southwire 250 ft 12-2 uf-b gray outdoor cable',
    'elec_emt_half':             'homedepot.com emt conduit 1/2 inch 10 ft',
    'elec_emt_3_4':              'homedepot.com emt conduit 3/4 inch 10 ft',
    'elec_pvc_conduit_half':     'homedepot.com pvc conduit 1/2 inch 10 ft schedule 40',
    'elec_flex_conduit':         'homedepot.com flexible metal conduit 1/2 inch 25 ft',
    'elec_conduit_fittings':     'homedepot.com halex 1/2 in emt compression connector 10 pack',
    'elec_box_old_work':         'homedepot.com old work electrical box 1-gang',
    'elec_box_new_work':         'homedepot.com carlon 1-gang new work electrical box nail on',
    'elec_junction_box':         'homedepot.com raco 4 in square metal electrical junction box',
    'elec_wp_box':               'homedepot.com weatherproof electrical box 1-gang',
    'elec_outlet_20a':           'homedepot.com 20 amp tamper resistant duplex outlet white',
    'elec_outlet_usb':           'homedepot.com leviton 20 amp type-a type-c usb duplex outlet receptacle',
    'elec_outlet_wp_cover':      'homedepot.com weatherproof outlet cover in-use',
    'elec_smart_switch':         'homedepot.com kasa smart wifi single pole light switch 1 pack',
    'elec_switch_3way':          'homedepot.com 3-way switch 15 amp decorator',
    'elec_occupancy_switch':     'homedepot.com occupancy sensor switch motion',
    # Plumbing
    'plumb_pex_1in':             'homedepot.com apollo 1 in x 100 ft pex pipe blue',
    'plumb_copper_3_4':          'homedepot.com 3/4 in x 10 ft copper type l pipe',
    'plumb_cpvc_half':           'homedepot.com charlotte 1/2 in x 10 ft cpvc cts pipe',
    'plumb_cpvc_3_4':            'homedepot.com charlotte 3/4 in x 10 ft cpvc cts pipe',
    'plumb_abs_3in':             'homedepot.com 3 in x 10 ft abs dwv pipe',
    'plumb_pvc_3in':             'homedepot.com 3 in x 10 ft pvc dwv foam core pipe',
    'plumb_pvc_4in':             'homedepot.com 4 in x 10 ft pvc dwv foam core pipe',
    'plumb_pex_elbow_half':      'homedepot.com apollo 1/2 in pex barb 90 degree elbow',
    'plumb_pex_tee_half':        'homedepot.com apollo 1/2 in pex barb tee',
    'plumb_pex_coupling_half':   'homedepot.com apollo 1/2 in pex barb coupling',
    'plumb_copper_elbow_half':   'homedepot.com 1/2 in copper pressure 90 degree elbow',
    'plumb_copper_tee_half':     'homedepot.com 1/2 in copper pressure tee fitting',
    'plumb_pvc_elbow_2in':       'homedepot.com 2 in pvc dwv 90 degree hub elbow',
    'plumb_pvc_tee_2in':         'homedepot.com 2 in pvc dwv sanitary tee',
    'plumb_brass_adapter':       'homedepot.com 1/2 in brass mip to sweat adapter',
    'plumb_ball_valve_half':     'homedepot.com 1/2 in brass full port ball valve single 1-pack',
    'plumb_ball_valve_3_4':      'homedepot.com 3/4 in brass full port ball valve',
    'plumb_angle_stop':          'homedepot.com 1/2 in compression x 3/8 in angle stop valve',
    'plumb_check_valve':         'homedepot.com 1/2 in brass swing check valve',
    'plumb_prv':                 'homedepot.com watts temperature pressure relief valve water heater 3/4 in',
    'plumb_p_trap':              'homedepot.com 1-1/2 in white plastic p-trap',
    'plumb_wax_ring':            'homedepot.com toilet wax ring with flange',
    # HVAC
    'hvac_flex_duct_6':          'homedepot.com master flow 6 in x 25 ft insulated flexible duct r-6',
    'hvac_flex_duct_8':          'homedepot.com master flow 8 in x 25 ft insulated flexible duct r-6',
    'hvac_rigid_duct_lf':        'homedepot.com master flow 6 in x 5 ft galvanized round sheet metal duct',
    'hvac_duct_insulation':      'homedepot.com owens corning duct wrap insulation r-6 fiberglass roll',
    'hvac_duct_mastic':          'homedepot.com hardcast rcd 6 1 gal water-based ductboard sealant brush grade',
    'hvac_duct_tape':            'homedepot.com nashua 557 ul 181b-fx hvac foil tape 60 yd roll',
    'hvac_duct_hangers':         'homedepot.com 1/2 in x 100 ft galvanized hanger strap roll duct support',
    'hvac_line_set':             'homedepot.com mrcool 1/4 in x 3/8 in x 25 ft insulated copper line set mini split',
    'hvac_condensate_pump':      'homedepot.com little giant vcma-15uls 115v automatic condensate removal pump',
    'hvac_disconnect':           'homedepot.com square d 60 amp 240-volt non-fused ac disconnect',
    'hvac_pad':                  'homedepot.com diversitech 32 in x 32 in x 3 in plastic equipment pad',
    'hvac_thermostat_wire':      'homedepot.com southwire 18/5 thermostat wire 250 ft solid copper',
    'hvac_bath_fan':             'homedepot.com broan-nutone 80 cfm ceiling bath exhaust fan',
    'hvac_range_hood':           'homedepot.com broan-nutone 30 in convertible under cabinet range hood stainless',
    'hvac_dryer_vent':           'homedepot.com everbilt 4 in dryer vent installation kit periscope hood clamps',
    # Siding
    'siding_vinyl_trim_coil':    'homedepot.com gibraltar 24 in x 50 ft aluminum trim coil white',
    'siding_f_channel':          'homedepot.com vinyl siding f-channel 12 ft 1/2 in white',
    'siding_starter_strip':      'homedepot.com vinyl siding starter strip 12 ft',
    'siding_undersill_trim':     'homedepot.com vinyl siding undersill finish trim 12 ft white',
    'siding_fiber_cement_shake': 'homedepot.com james hardie hardieshingle 15.25 in straight edge fiber cement siding',
    'siding_fiber_trim':         'homedepot.com james hardie hardietrim 5/4 in x 5.5 in x 12 ft fiber cement trim board',
    'siding_fiber_caulk':        'homedepot.com quikrete 10.1 oz acrylic fiber cement siding caulk single tube',
    'siding_stucco_finish':      'homedepot.com quikrete 80 lb finish coat stucco',
    'siding_stucco_mesh':        'homedepot.com amico self-furring 2.5 lb galvanized expanded metal stucco lath',
    'siding_stucco_bond':        'homedepot.com quikrete concrete bonding adhesive 1 gallon',
    'siding_metal_trim':         'homedepot.com amerimax 24 in x 50 ft white aluminum trim coil',
    'siding_flashing':           'homedepot.com amerimax 6 in x 10 ft aluminum continuous counter flashing mill finish',
    'siding_caulk':              'homedepot.com ge silicone 2+ 10.1 oz exterior window and door sealant white',
    'siding_nails':              'homedepot.com grip-rite 2 in aluminum vinyl siding nail 1 lb box',
    'siding_fiber_screws':       'homedepot.com simpson strong-tie quik drive 1-5/8 in hardie board fiber cement screw collated',
    # Flooring
    'floor_sheet_vinyl':         'homedepot.com trafficmaster 12 ft wide sheet vinyl flooring',
    'floor_vct':                 'homedepot.com armstrong 12 in x 12 in vct vinyl composition tile',
    'floor_bamboo':              'homedepot.com home decorators collection bamboo flooring 5/8 in tongue and groove',
    'floor_marble':              'homedepot.com carrara marble 12 in x 12 in polished floor and wall tile',
    'floor_travertine':          'homedepot.com msi 12 in x 12 in ivory travertine floor and wall tile',
    'floor_tile_large':          'homedepot.com msi 24 in x 24 in porcelain floor and wall tile',
    'floor_mosaic':              'homedepot.com daltile 12 in x 12 in mosaic tile',
    'floor_thinset':             'homedepot.com custom building products versabond 50 lb gray fortified thinset mortar',
    'floor_grout_sanded':        'homedepot.com custom building products polyblend plus 25 lb pewter sanded grout',
    'floor_grout_unsanded':      'homedepot.com custom building products polyblend plus 10 lb bright white unsanded grout',
    'floor_tile_sealer':         'homedepot.com miracle sealants 511 impregnator 1 gallon penetrating sealer',
    'floor_transition_t':        'homedepot.com m-d building products t-molding transition strip 36 in oak',
    'floor_transition_reducer':  'homedepot.com m-d building products reducer transition 36 in oak',
    'floor_self_level':          'homedepot.com custom building products levelquik rs 50 lb self-leveling underlayment',
    'floor_moisture_barrier':    'homedepot.com roberts 100 sq ft 6 mil moisture barrier film',
    # Drywall
    'drywall_sheet_moisture':    'homedepot.com 1/2 in x 4 ft x 8 ft moisture resistant green board gypsum drywall',
    'drywall_sheet_fire':        'homedepot.com 5/8 in x 4 ft x 8 ft type x fire rated gypsum drywall',
    'drywall_sheet_mold':        'homedepot.com usg 1/2 in x 4 ft x 8 ft sheetrock brand mold tough gypsum panel',
    'drywall_setting_compound':  'homedepot.com usg sheetrock easy sand 90 setting type joint compound 18 lb bag',
    'drywall_mesh_tape':         'homedepot.com strait-flex 300 ft self adhesive fiberglass drywall mesh tape',
    'drywall_bullnose_bead':     'homedepot.com trim-tex 8 ft bullnose corner bead vinyl',
    'drywall_l_bead':            'homedepot.com 10 ft vinyl drywall l-bead trim edge',
    'drywall_texture_skip_trowel':'homedepot.com homax pro grade 2.2 qt skip trowel wall texture',
    'drywall_skim_coat':         'homedepot.com plus 3 joint compound skim coat ready mix 4.5 gal',
    'drywall_sheet_sound':       'homedepot.com quietrock ez-snap 5/8 in x 4 ft x 8 ft soundproof drywall',
    'drywall_resilient_channel': 'homedepot.com 1/2 in x 12 ft 25 gauge resilient channel drywall',
    'insulation_batt_r13':       'homedepot.com owens corning r-13 kraft faced fiberglass insulation batt 15 in x 93 in',
    # Painting
    'paint_deck_stain_mat':      'homedepot.com behr premium 1 gal semi-transparent waterproofing stain and sealer',
    'paint_epoxy_mat':           'homedepot.com rust-oleum epoxyshield 2 gal gray garage floor epoxy kit',
    'paint_elastomeric_mat':     'homedepot.com behr premium 1 gal white elastomeric masonry stucco brick paint',
    'paint_shellac_primer':      'homedepot.com zinsser bulls eye 1 gal white shellac primer sealer',
    # Roofing
    'mat_synthetic_slate':       'homedepot.com davinci bellaforte slate composite roofing shingle',
    'roof_sealant':              'homedepot.com henry 1 gal 209xr extra-thick elastomeric roof patching cement',
    'pipe_boot':                 'homedepot.com oatey 4 in thermoplastic no-calk roof flashing pipe boot',
    'step_flashing_lf':          'homedepot.com amerimax 5 in x 7 in x 10 in aluminum step flashing',
    'gutter_lf':                 'homedepot.com amerimax 10 ft k style white aluminum gutter',
    'gutter_downspout':          'homedepot.com amerimax 10 ft x 2 in x 3 in white aluminum downspout',
}

EXTRACT_SYSTEM = """You are a Home Depot pricing extractor.

You will receive:
- A target item description (name, unit, type, notes) from a contractor pricing list
- The raw text content of a Home Depot product page

Your job: decide whether the page represents the *exact* item being priced, and if
so, extract the canonical price and HD item_id. If the page is a close-but-wrong
product (wrong size, wrong material, wrong category), return NULL with a one-line
reason. Do not guess. Prefer NULL over a wrong match — we have a review gate
after you.

Respond ONLY with a single JSON object, no prose:
{
  "matches": true | false,
  "reason": "<why it matches or doesn't; one sentence>",
  "product_title": "<hd product title, or null>",
  "item_id": "<hd item id string, or null>",
  "price": <number in USD, or null>,
  "price_unit": "<'each'|'sqft'|'lf'|'gallon'|'tube'|... matching the target unit when possible>",
  "confidence": "high" | "medium" | "low" | null
}
"""


def tavily_search(query, max_results=5):
    """Tavily search with raw content. Returns list[{url, title, content, raw_content}]."""
    if not TAVILY_KEY:
        raise RuntimeError('TAVILY_API_KEY missing — cannot run search')
    body = json.dumps({
        'api_key': TAVILY_KEY,
        'query': query,
        'search_depth': 'advanced',
        'include_raw_content': True,
        'include_domains': ['homedepot.com'],
        'max_results': max_results,
    }).encode()
    req = urllib.request.Request(TAVILY_URL, data=body,
                                 headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=60) as r:
        d = json.loads(r.read())
    return d.get('results') or []


def pick_hd_product(results):
    """From tavily results, pick the first one whose URL matches an HD /p/<slug>/<item_id> product URL."""
    for r in results:
        url = r.get('url') or ''
        m = HD_URL_RX.search(url)
        if m:
            return r, m.group(1)
    return None, None


def haiku_extract(target, page_title, page_url, page_content):
    """Ask Haiku (via OpenRouter) whether page matches and extract price/SKU."""
    if not OPENROUTER_KEY:
        raise RuntimeError('OPENROUTER_API_KEY missing — cannot run extract')
    user = f"""TARGET ITEM:
  name: {target['item_name']}
  unit: {target['unit']}
  type: {target['type']}
  notes: {target.get('notes', '')}

HD PRODUCT PAGE:
  url: {page_url}
  title: {page_title}

PAGE CONTENT (truncated):
{page_content[:6000]}
"""
    body = json.dumps({
        'model': OPENROUTER_MODEL,
        'temperature': 0,
        'max_tokens': 400,
        'messages': [
            {'role': 'system', 'content': EXTRACT_SYSTEM},
            {'role': 'user', 'content': user},
        ],
        'response_format': {'type': 'json_object'},
    }).encode()
    req = urllib.request.Request(
        OPENROUTER_URL, data=body,
        headers={
            'Authorization': f'Bearer {OPENROUTER_KEY}',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://paperclip.ing',
            'X-Title': 'instabid-tea203',
        },
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        d = json.loads(r.read())
    txt = d['choices'][0]['message']['content']
    try:
        return json.loads(txt)
    except json.JSONDecodeError:
        # Strip fences if the model added them
        stripped = re.sub(r'^```(?:json)?\n?|```$', '', txt.strip(), flags=re.M)
        return json.loads(stripped)


def run_one(row):
    """Execute the full Road B pipeline for one gap-list row. Returns a review entry dict."""
    query = QUERY_OVERRIDES.get(row['pricing_key']) or f"homedepot.com {row['item_name']}"
    entry = {
        'pricing_key':   row['pricing_key'],
        'item_name':     row['item_name'],
        'unit':          row['unit'],
        'type':          row['type'],
        'syncable':      row['syncable'],
        'notes':         row.get('notes', ''),
        'search_query':  query,
        'hd_url':        None,
        'item_id':       None,
        'match_title':   None,
        'match_price':   None,
        'price_unit':    None,
        'confidence':    None,
        'haiku_reason':  None,
        'haiku_matches': None,
        'error':         None,
        'source':        'web_search',
    }
    try:
        results = tavily_search(query)
        hit, item_id = pick_hd_product(results)
        if not hit:
            entry['confidence'] = 'no_match'
            entry['haiku_reason'] = 'Tavily returned no HD /p/ product URL'
            return entry
        entry['hd_url']   = hit.get('url')
        entry['item_id']  = item_id
        page_content = hit.get('raw_content') or hit.get('content') or ''
        extracted = haiku_extract(row, hit.get('title', ''), hit.get('url', ''), page_content)
        entry['haiku_matches'] = bool(extracted.get('matches'))
        entry['haiku_reason']  = extracted.get('reason')
        entry['match_title']   = extracted.get('product_title')
        entry['match_price']   = extracted.get('price')
        entry['price_unit']    = extracted.get('price_unit')
        entry['confidence']    = extracted.get('confidence') if extracted.get('matches') else 'no_match'
        if extracted.get('item_id'):
            entry['item_id'] = str(extracted['item_id'])
    except urllib.error.HTTPError as e:
        entry['error'] = f'HTTP {e.code}: {e.reason}'
    except Exception as e:
        entry['error'] = f'{type(e).__name__}: {e}'
    return entry


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--trade', help='Filter to one trade key (e.g. cabinets_and_countertops)')
    parser.add_argument('--pricing-keys', help='Comma-separated pricing_keys to limit the run')
    parser.add_argument('--out', help='Output JSON path (defaults to docs/tea-203/needs_review_<trade>.json)')
    parser.add_argument('--sleep', type=float, default=1.0, help='Seconds between items')
    args = parser.parse_args()

    gap = json.load(open(GAP))
    if args.trade:
        gap = [r for r in gap if r['trade'] == args.trade]
    if args.pricing_keys:
        wanted = set(k.strip() for k in args.pricing_keys.split(','))
        gap = [r for r in gap if r['pricing_key'] in wanted]

    if not gap:
        print('No matching rows in gap list', file=sys.stderr)
        sys.exit(2)

    if not TAVILY_KEY or not OPENROUTER_KEY:
        print('Missing required env: TAVILY_API_KEY and/or OPENROUTER_API_KEY', file=sys.stderr)
        sys.exit(3)

    out_path = args.out or os.path.join(
        ROOT, f"docs/tea-203/needs_review_{args.trade or 'all'}.json"
    )

    print(f'Processing {len(gap)} items → {out_path}', flush=True)
    results = []
    for i, row in enumerate(gap, 1):
        r = run_one(row)
        results.append(r)
        conf = r['confidence'] or 'error'
        print(f'  [{i:>3}/{len(gap)}] {row["pricing_key"]:<35} → {conf:<10} '
              f'{r["item_id"] or "(none)":<12} price={r["match_price"]}', flush=True)
        time.sleep(args.sleep)

    with open(out_path, 'w') as f:
        json.dump(results, f, indent=2)

    by_conf = {}
    for r in results:
        k = r['confidence'] or 'error'
        by_conf[k] = by_conf.get(k, 0) + 1
    print('\nConfidence breakdown:', by_conf)


if __name__ == '__main__':
    main()
