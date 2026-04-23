#!/usr/bin/env python3
"""
TEA-203 — Road B v2: Tavily `include_answer` + Haiku price sanity-check.

v1 used Tavily's `raw_content` to feed HD PDP text into Haiku. HD blocks
scrapers so `raw_content` usually comes back as ~150 chars of title-only
metadata and Haiku sees no dollar amount.

v2 switches to Tavily's LLM-synthesized `answer` field, which pulls the
current HD price from live search results (verified $169.99 for Hampton
Bay 30" base cabinet). We then ask Haiku — via OpenRouter — to parse that
answer into a strict JSON object and sanity-check it against the target
item description.

Inputs : docs/tea-203/gap_list_parsed.json
Outputs: docs/tea-203/needs_review_<trade>.json (append / overwrite)

Env    : TAVILY_API_KEY      (required)
         OPENROUTER_API_KEY  (required)

Usage:
  python3 scripts/tea203_road_b_v2.py --trade cabinets_and_countertops
  python3 scripts/tea203_road_b_v2.py --all
  python3 scripts/tea203_road_b_v2.py --only-missing-price   # re-run rows with
                                                              # match_price=null
"""
import argparse, json, os, re, sys, time, urllib.request, urllib.error

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAP  = os.path.join(ROOT, 'docs/tea-203/gap_list_parsed.json')
DOCS = os.path.join(ROOT, 'docs/tea-203')

TAVILY_KEY     = os.environ.get('TAVILY_API_KEY', '').strip()
OPENROUTER_KEY = os.environ.get('OPENROUTER_API_KEY', '').strip()
OPENROUTER_MODEL = os.environ.get('TEA203_MODEL', 'anthropic/claude-haiku-4-5')

TAVILY_URL     = 'https://api.tavily.com/search'
OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions'

HD_URL_RX = re.compile(r'homedepot\.com/p/[^/]+/(\d+)')

# Trade → file-suffix mapping. gap_list trade keys → needs_review_<suffix>.json
TRADE_TO_FILE = {
    'cabinets_and_countertops': 'cabinets',
    'electrical':                'electrical',
    'plumbing':                  'plumbing',
    'hvac':                      'hvac',
    'drywall':                   'drywall',
    'flooring':                  'flooring',
    'painting':                  'painting',
    'roofing':                   'roofing',
    'siding':                    'siding',
}

# Price-targeted query template per pricing_key. Worded to coax Tavily's
# answer-synthesizer into surfacing a current HD price.
def build_query(row):
    name = row['item_name']
    unit = row.get('unit', '')
    return f'current price of {name} at Home Depot'

EXTRACT_SYSTEM = """You parse short web-search answers into JSON.

Input is (1) a target item description, and (2) a short LLM-synthesized
answer from a web search. Your job: pull the USD price from the answer
if-and-only-if the answer plausibly describes the target item, and return
a strict JSON object.

If the answer gives a single unambiguous price for the right item → return it.
If the answer gives a range (e.g. "$150 to $300") → return the midpoint and
confidence='medium'.
If the answer is about a different product, unclear, or has no dollar figure
→ return price=null and confidence='no_match'.

Respond ONLY with this JSON object, nothing else:
{
  "price": <number in USD, or null>,
  "price_unit": "<'each'|'sqft'|'lf'|'gallon'|'tube'|... matching target unit if possible>",
  "confidence": "high" | "medium" | "low" | "no_match",
  "reason": "<one short sentence>"
}
"""


def tavily_answer(query):
    body = json.dumps({
        'api_key':         TAVILY_KEY,
        'query':           query,
        'search_depth':    'advanced',
        'include_answer':  True,
        'include_domains': ['homedepot.com'],
        'max_results':     5,
    }).encode()
    req = urllib.request.Request(TAVILY_URL, data=body,
                                 headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=60) as r:
        d = json.loads(r.read())
    return d.get('answer') or '', d.get('results') or []


def pick_hd_product(results):
    for r in results:
        url = r.get('url') or ''
        m = HD_URL_RX.search(url)
        if m:
            return r, m.group(1)
    return None, None


def haiku_price(target, answer_text):
    user = f"""TARGET ITEM:
  name: {target['item_name']}
  unit: {target['unit']}
  type: {target['type']}
  notes: {target.get('notes', '')}

WEB SEARCH ANSWER:
{answer_text}
"""
    body = json.dumps({
        'model':           OPENROUTER_MODEL,
        'temperature':     0,
        'max_tokens':      200,
        'messages': [
            {'role': 'system', 'content': EXTRACT_SYSTEM},
            {'role': 'user',   'content': user},
        ],
        'response_format': {'type': 'json_object'},
    }).encode()
    req = urllib.request.Request(
        OPENROUTER_URL, data=body,
        headers={
            'Authorization': f'Bearer {OPENROUTER_KEY}',
            'Content-Type':  'application/json',
            'HTTP-Referer':  'https://paperclip.ing',
            'X-Title':       'instabid-tea203',
        },
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        d = json.loads(r.read())
    txt = d['choices'][0]['message']['content']
    try:
        return json.loads(txt)
    except json.JSONDecodeError:
        stripped = re.sub(r'^```(?:json)?\n?|```$', '', txt.strip(), flags=re.M)
        return json.loads(stripped)


def run_one(row):
    query = build_query(row)
    entry = {
        'pricing_key':   row['pricing_key'],
        'item_name':     row['item_name'],
        'unit':          row['unit'],
        'type':          row['type'],
        'syncable':      row.get('syncable'),
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
        answer, results = tavily_answer(query)
        hit, item_id = pick_hd_product(results)
        if hit:
            entry['hd_url']     = hit.get('url')
            entry['item_id']    = item_id
            entry['match_title']= hit.get('title')

        if not answer:
            entry['confidence']   = 'no_match'
            entry['haiku_reason'] = 'Tavily returned no synthesized answer'
            return entry

        parsed = haiku_price(row, answer)
        entry['match_price']   = parsed.get('price')
        entry['price_unit']    = parsed.get('price_unit') or row['unit']
        entry['confidence']    = parsed.get('confidence') or 'no_match'
        entry['haiku_reason']  = parsed.get('reason')
        entry['haiku_matches'] = entry['confidence'] in ('high', 'medium')
    except urllib.error.HTTPError as e:
        entry['error'] = f'HTTP {e.code}: {e.reason}'
    except Exception as e:
        entry['error'] = f'{type(e).__name__}: {e}'
    return entry


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--trade', help='gap_list trade key (e.g. cabinets_and_countertops)')
    parser.add_argument('--all', action='store_true', help='Run every trade')
    parser.add_argument('--pricing-keys', help='Comma-separated pricing_keys to limit the run')
    parser.add_argument('--only-missing-price', action='store_true',
                        help='Re-run only rows in existing needs_review JSON with match_price=null')
    parser.add_argument('--sleep', type=float, default=0.8)
    parser.add_argument('--limit', type=int, default=0,
                        help='Max items to process in this run (0 = no limit)')
    args = parser.parse_args()

    if not TAVILY_KEY or not OPENROUTER_KEY:
        print('Missing TAVILY_API_KEY and/or OPENROUTER_API_KEY', file=sys.stderr)
        sys.exit(3)

    gap = json.load(open(GAP))

    trades = []
    if args.all:
        trades = sorted(TRADE_TO_FILE.keys())
    elif args.trade:
        trades = [args.trade]
    else:
        print('pass --trade or --all', file=sys.stderr)
        sys.exit(2)

    total_items_done = 0

    for trade in trades:
        if trade not in TRADE_TO_FILE:
            print(f'skip unknown trade {trade}', file=sys.stderr)
            continue

        file_suffix = TRADE_TO_FILE[trade]
        out_path    = os.path.join(DOCS, f'needs_review_{file_suffix}.json')

        # Load prior results so we can update in-place instead of clobbering.
        prior = []
        if os.path.exists(out_path):
            prior = json.load(open(out_path))
        prior_by_key = {r['pricing_key']: r for r in prior}

        rows = [r for r in gap if r['trade'] == trade]
        if args.pricing_keys:
            wanted = set(k.strip() for k in args.pricing_keys.split(','))
            rows = [r for r in rows if r['pricing_key'] in wanted]

        if args.only_missing_price:
            rows = [r for r in rows
                    if not prior_by_key.get(r['pricing_key'], {}).get('match_price')]

        if args.limit and args.limit > 0:
            remaining = args.limit - total_items_done
            if remaining <= 0:
                break
            rows = rows[:remaining]

        if not rows:
            print(f'[{trade}] nothing to do')
            continue

        print(f'[{trade}] processing {len(rows)} items → {out_path}', flush=True)

        for i, row in enumerate(rows, 1):
            r = run_one(row)
            prior_by_key[row['pricing_key']] = r
            conf = r['confidence'] or 'error'
            print(f'  [{i:>3}/{len(rows)}] {row["pricing_key"]:<35} → {conf:<10} '
                  f'price={r["match_price"]}', flush=True)
            time.sleep(args.sleep)
            total_items_done += 1
            if args.limit and total_items_done >= args.limit:
                break

        # Preserve original ordering when possible — pricing_key order in gap list.
        gap_order = [r['pricing_key'] for r in gap if r['trade'] == trade]
        final = [prior_by_key[k] for k in gap_order if k in prior_by_key]
        # Any leftover entries not in gap (rare)
        for k, v in prior_by_key.items():
            if k not in gap_order:
                final.append(v)

        with open(out_path, 'w') as f:
            json.dump(final, f, indent=2)

        by_conf = {}
        for r in final:
            k = r.get('confidence') or 'error'
            by_conf[k] = by_conf.get(k, 0) + 1
        priced = sum(1 for r in final if r.get('match_price'))
        print(f'[{trade}] wrote {len(final)} rows, {priced} priced, by_conf={by_conf}')

        if args.limit and total_items_done >= args.limit:
            break


if __name__ == '__main__':
    main()
