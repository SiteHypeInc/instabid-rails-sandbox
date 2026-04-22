#!/usr/bin/env python3
"""
TEA-203 — BigBox search for Cabinets & Countertops gap list items.
Emits docs/tea-203/needs_item_id_cabinets.json for Johnny review.
"""
import json, os, sys, time, urllib.parse, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY  = open('/tmp/bigbox_key').read().strip()
GAP  = json.load(open(os.path.join(ROOT, 'docs/tea-203/gap_list_parsed.json')))
OUT  = os.path.join(ROOT, 'docs/tea-203/needs_item_id_cabinets.json')

# Primary + fallback search terms per pricing_key. BigBox HD search chokes on
# many 2-word phrases, so fallbacks drop to a single anchor noun. First term
# that returns >0 results wins.
SEARCH_TERMS = {
    'cab_base_30_stock':        ['hampton bay base cabinet 30 inch', 'base kitchen cabinet 30'],
    'cab_wall_30_stock':        ['hampton bay wall cabinet 30 inch', 'wall kitchen cabinet 30'],
    'cab_tall_stock':           ['hampton bay pantry cabinet', 'tall kitchen cabinet 84'],
    'cab_base_30_semi':         ['kraftmaid base cabinet 30', 'semi custom base cabinet'],
    'cab_wall_30_semi':         ['kraftmaid wall cabinet 30', 'semi custom wall cabinet'],
    'cab_base_custom_lf':       ['custom base cabinet', 'custom kitchen cabinet'],
    'cab_wall_custom_lf':       ['custom wall cabinet', 'custom kitchen cabinet'],
    'cab_hardware_pull':        ['cabinet pull handle', 'cabinet hardware pull'],
    'cab_hardware_knob':        ['cabinet hardware knob', 'cabinet knob satin nickel'],
    'cab_hinge_soft_close':     ['soft close cabinet hinge', 'cabinet hinge'],
    'cab_drawer_slide':         ['soft close drawer slides', 'drawer slide'],
    'cab_lazy_susan':           ['lazy susan cabinet', 'lazy susan'],
    'cab_pullout_shelf':        ['cabinet pull out shelf', 'pull out shelf'],
    'cab_crown_lf':             ['cabinet crown molding', 'crown molding'],
    'cab_filler':               ['cabinet filler strip', 'hampton bay filler'],
    'cab_end_panel':            ['cabinet end panel', 'cabinet finish panel'],
    'cab_reface_lf':            ['cabinet refacing kit', 'cabinet reface'],
    'cab_paint_door':           ['cabinet door paint kit', 'cabinet paint kit'],
    'counter_laminate_sqft':    ['formica laminate countertop', 'formica sheet'],
    'counter_butcher_sqft':     ['butcher block', 'hampton bay butcher block'],
    'counter_solid_surface_sqft':['corian solid surface', 'solid surface countertop'],
    'counter_quartz_sqft':      ['msi quartz', 'quartz slab'],
    'counter_granite_sqft':     ['granite slab', 'granite countertop'],
    'counter_marble_sqft':      ['marble slab', 'marble countertop'],
    'counter_concrete_sqft':    ['concrete countertop mix', 'concrete mix'],
    'counter_install_sqft':     ['countertop installation'],
    'counter_edge_basic_lf':    ['countertop edge', 'edge profile countertop'],
    'counter_edge_premium_lf':  ['premium countertop edge', 'countertop edge'],
    'backsplash_subway_sqft':   ['subway tile backsplash', 'subway tile'],
    'backsplash_mosaic_sqft':   ['mosaic tile backsplash', 'mosaic tile'],
    'backsplash_install_sqft':  ['backsplash installation'],
    'counter_sink_cutout':      ['undermount sink', 'sink cutout'],
    'counter_cooktop_cutout':   ['cooktop installation', 'cooktop'],
}

def classify_confidence(row, hit, hit_title, hit_price):
    syncable = row['syncable'].upper()
    if syncable == 'NO':
        return 'specialty'
    if not hit:
        return 'no_match'
    name_tokens = [t.lower() for t in row['item_name'].replace('(', ' ').replace(')', ' ').split() if len(t) > 2]
    title_l = hit_title.lower()
    match_count = sum(1 for t in name_tokens if t in title_l)
    if syncable == 'PARTIAL':
        return 'low'
    if hit_price is None or hit_price <= 0:
        return 'medium'
    ratio = match_count / max(len(name_tokens), 1)
    if ratio >= 0.5:
        return 'high'
    if ratio >= 0.3:
        return 'medium'
    return 'low'

def search_one(term, retries=2):
    q = {'api_key': KEY, 'type': 'search', 'search_term': term, 'zip_code': '10001', 'page': '1'}
    url = 'https://api.bigboxapi.com/request?' + urllib.parse.urlencode(q)
    last_err = None
    for _ in range(retries):
        try:
            with urllib.request.urlopen(url, timeout=45) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            if e.code == 500:
                last_err = e
                time.sleep(1.5)
                continue
            raise
    raise last_err

def extract_hit(data):
    results = data.get('search_results') or []
    if not results:
        return None, None, None, None
    top = results[0]
    p   = top.get('product') or top
    offers = top.get('offers') or {}
    price = (offers.get('primary') or {}).get('price') or p.get('price')
    return p.get('item_id'), p.get('title'), price, p.get('link')

cabs = [r for r in GAP if r['trade'] == 'cabinets_and_countertops']
print(f'Searching {len(cabs)} cabinets items (with fallback terms)...', flush=True)

out = []
for i, row in enumerate(cabs, 1):
    terms = SEARCH_TERMS.get(row['pricing_key']) or [row['item_name']]
    if isinstance(terms, str):
        terms = [terms]

    winning_term = terms[0]
    item_id = title = price = link = None
    total_results = 0
    error = None
    for t in terms:
        try:
            data = search_one(t)
        except Exception as e:
            error = f'{type(e).__name__}: {e}'
            continue
        total_results = len(data.get('search_results') or [])
        if total_results > 0:
            winning_term = t
            item_id, title, price, link = extract_hit(data)
            break
        time.sleep(0.4)

    entry = {
        'pricing_key':   row['pricing_key'],
        'item_name':     row['item_name'],
        'unit':          row['unit'],
        'type':          row['type'],
        'syncable':      row['syncable'],
        'notes':         row['notes'],
        'search_term':   winning_term,
        'tried_terms':   terms,
        'item_id':       item_id,
        'match_title':   title,
        'match_price':   float(price) if price else None,
        'match_url':     link,
        'results_total': total_results,
        'confidence':    None,
        'error':         error,
    }
    entry['confidence'] = classify_confidence(row, entry['item_id'], entry['match_title'] or '', entry['match_price'])
    out.append(entry)
    print(f'  [{i:>2}/{len(cabs)}] {row["pricing_key"]:<35} → {entry["confidence"]:<10} {entry["item_id"] or "(none)":<12} {(entry["match_title"] or "")[:50]}', flush=True)
    time.sleep(0.8)

with open(OUT, 'w') as f:
    json.dump(out, f, indent=2)

by_conf = {}
for e in out:
    by_conf[e['confidence']] = by_conf.get(e['confidence'], 0) + 1
print()
print(f'Wrote {OUT}')
print('Confidence breakdown:', by_conf)
