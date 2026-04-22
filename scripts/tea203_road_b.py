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
    'elec_wire_10_2':            'homedepot.com romex 10/2 250 ft nm-b cable',
    'elec_wire_10_3':            'homedepot.com romex 10/3 250 ft nm-b cable',
    'elec_wire_6_3_lf':          'homedepot.com romex 6/3 nm-b cable per foot',
    'elec_thhn_12':              'homedepot.com thhn 12 awg 500 ft wire',
    'elec_uf_cable':             'homedepot.com uf-b 12/2 250 ft cable',
    'elec_emt_half':             'homedepot.com emt conduit 1/2 inch 10 ft',
    'elec_emt_3_4':              'homedepot.com emt conduit 3/4 inch 10 ft',
    'elec_pvc_conduit_half':     'homedepot.com pvc conduit 1/2 inch 10 ft schedule 40',
    'elec_flex_conduit':         'homedepot.com flexible metal conduit 1/2 inch 25 ft',
    'elec_conduit_fittings':     'homedepot.com emt conduit fittings assortment kit',
    'elec_box_old_work':         'homedepot.com old work electrical box 1-gang',
    'elec_box_new_work':         'homedepot.com new work electrical box 1-gang',
    'elec_junction_box':         'homedepot.com junction box 4x4 metal',
    'elec_wp_box':               'homedepot.com weatherproof electrical box 1-gang',
    'elec_outlet_20a':           'homedepot.com 20 amp tamper resistant duplex outlet white',
    'elec_outlet_usb':           'homedepot.com usb outlet combo 20 amp',
    'elec_outlet_wp_cover':      'homedepot.com weatherproof outlet cover in-use',
    'elec_smart_switch':         'homedepot.com smart switch wifi single pole',
    'elec_switch_3way':          'homedepot.com 3-way switch 15 amp decorator',
    'elec_occupancy_switch':     'homedepot.com occupancy sensor switch motion',
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
