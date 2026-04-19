# InstaBid — Product Spec

**"Dude, it's amazing! I don't touch a thing and it's all done for me. I just go to work!"**

That's the target. Every feature, every decision, every line of code serves that sentence.

---

## What InstaBid Is

InstaBid is a multi-trade estimating platform for small and mid-size contractors. A homeowner fills out a form on the contractor's website. InstaBid does the math — real material prices, regional labor rates, waste factors, pitch multipliers, the works. The homeowner gets a professional PDF estimate, a scope-of-work contract, and a Stripe payment link in their inbox within minutes. The contractor gets a qualified lead with full project details in their dashboard, ready to close.

No spreadsheets. No manual calculations. No chasing leads. The contractor sets up once, embeds a script on their website, and goes to work.

**Built by a contractor, for contractors.** After 30 years in the trades, the founder got tired of losing jobs to the guy who quoted faster. So he built the tool he always wished he had.

---

## What Works Today (Live in Production)

### Contractor Side
- **Sign up / Login** — create account, 14-day free trial, no credit card required
- **Company Profile** — business info, logo, brand colors (primary, secondary, accent, label)
- **Business Settings** — tax rate, default markup %, labor rate override, display options (show/hide labor breakdown, materials breakdown, equipment costs)
- **Integrations** — Stripe (accept deposits/payments), Google Maps API (property locations), Google Calendar sync
- **Embed Script** — 5 lines of code, drops the estimate form onto any website (WordPress, Wix, Squarespace, plain HTML)
- **Price Adjustments** — full editable pricebook across all 8 trades: Roofing, HVAC, Electrical, Plumbing, Flooring, Painting, Drywall, Siding. Labor rates, fixture installs, material costs, multipliers (pitch, access, ceiling height, finish level) — all contractor-editable
- **Estimate Tracker** — every estimate in a queue with customer info, trade, total, date. Click into any estimate for full breakdown (materials, labor, equipment, project details)
- **Contract Templates** — boilerplate contract included. Contractor can upload their own
- **Regional tab** — regional adjustments by location

### Customer (Homeowner) Side
- **Estimate Form** — select trade, enter project details (sqft, material type, pitch, stories, etc.), property address, contact info, optional photo upload
- **Instant Estimate** — real-time calculation displayed on screen with full scope breakdown
- **Email Delivery** — PDF estimate + contract + Stripe deposit payment link sent to homeowner's inbox automatically
- **Booking Calendar** — homeowner selects preferred start date from contractor's available dates (unavailable dates greyed out based on contractor's Google Calendar)
- **Deposit Payment** — Stripe checkout for deposit, linked directly from the estimate email

### The Full Loop (End to End)
1. Homeowner visits contractor's website
2. Fills out the estimate form (2 minutes)
3. InstaBid calculates everything — materials, labor, equipment, tax, markup
4. Homeowner receives email with PDF estimate, contract, and Stripe payment link
5. Homeowner pays deposit and picks a start date on the contractor's calendar
6. Contractor sees everything in their dashboard — project details, customer info, full material list (printable/emailable/CSV), booking on calendar
7. Contractor sends crew to the supplier on the scheduled date, materials are waiting on the loading dock
8. Contractor goes to work

**Time from form fill to deposit paid: under 10 minutes. Contractor touches nothing.**

---

## Pricing Tiers

| Plan | Price | What You Get |
|------|-------|-------------|
| Starter | Free forever | 10 estimates/month, basic roof & siding calcs, email notifications, PDF generation |
| Pro | $99/month | 1 trade, unlimited estimates, all calculations, full lead details, calendar sync, branded PDFs, real-time notifications |
| Business | $199/month | All 8 trades, up to 5 team members, lead assignment & routing, team performance dashboard, advanced analytics, phone support, API access |
| Enterprise | Custom | Multi-location, unlimited team, white-label widget, dedicated account manager, custom integrations, SLA guarantee |

14-day free trial on all paid plans. No credit card required. No per-lead charges ever.

---

## The 8 Trades (All Live)

Each trade has its own estimator with trade-specific form fields, material lists, labor calculations, and pricing keys.

1. **Roofing** — sqft, pitch, material type (3-tab/architectural/metal/tile/wood shake), stories, layers to tear off, chimneys, skylights, valleys, ridge vent, plywood replacement
2. **HVAC** — system type (furnace/AC/heat pump/mini split), efficiency level (standard/high), ductwork (new/repair), thermostat
3. **Electrical** — panel size (100A/200A), wire runs, outlets, switches (single/3-way), GFCI, breakers, fixtures, ceiling fans
4. **Plumbing** — fixture type (toilet/sink/faucet/shower/tub/disposal/dishwasher/ice maker), water heater (tank 40/50 gal, tankless gas/electric), repipe (PEX/copper), water systems (softener/sump pump), major jobs (main line/gas line)
5. **Flooring** — material (carpet 3 grades/vinyl/LVP/laminate 2 grades/engineered hardwood/solid hardwood/ceramic tile/porcelain tile), underlayment, baseboard
6. **Painting** — interior/exterior, finish (flat/eggshell/semi-gloss/satin), primer, sqft, rooms, surfaces
7. **Drywall** — new construction vs repair, sqft, rooms, ceiling height, finish level (3/4/5), texture (orange peel/knockdown/popcorn), sheet thickness (1/2"/5/8"), damage extent (minor/moderate/extensive)
8. **Siding** — material (vinyl/fiber cement/cedar wood/metal/stucco), housewrap, trim, corner posts, J-channel, fascia, fastener kit

### Pricing Architecture
Four-layer cascade — most specific wins:
1. **Contractor overrides** — contractor's own prices from their dashboard pricebook
2. **Platform defaults** (`default_pricings`) — InstaBid's baseline prices, refreshed by BigBox HD sync
3. **Hardcoded fallbacks** — last-resort values in the estimator code
4. **Regional multipliers** — state-level adjustments applied to material costs

Every pricing key is a flat value (e.g., `mat_arch = 44.96` per bundle) or a multiplier (e.g., `pitch_6_12 = 1.1`). The estimator reads the key, applies the math, outputs the line item.

---

## What's Shipping Now

### BigBox Pricing Sync (In Progress — This Week)
**Problem:** The ~200 platform default prices are from a one-time Home Depot scrape. Stale data = inaccurate estimates = contractor distrust.

**Solution:** BigBox API (bigboxapi.com) scrapes current HD prices on a 30-day cycle and updates `default_pricings` automatically.

**How it works:**
1. BigBox Collections runs scheduled scrapes of 89+ HD product SKUs across all 8 trades
2. Results arrive via webhook POST to a Rails endpoint
3. Prices cached in `material_prices` table with SKU, trade, price, unit, source, timestamp
4. Mapping layer connects each `material_prices` entry to `default_pricings` pricing keys
5. Fixture items (faucets, toilets, etc.) include a flat `labor_adder` because `default_pricings` values represent installed cost (material + labor bundled)
6. Sync runs, updates `default_pricings.value`. Estimators automatically use fresh prices — no code changes needed

**Status:** Proven in sandbox. 95 products, all 8 trades, live HD prices. Mapping layer with labor_adders working. Awaiting integration into Jesse's production Rails app.

**Regional pricing:** 6 ZIPs configured (Portland, Phoenix, Atlanta, New Jersey, Chicago, Dallas). For now, average across ZIPs into one national baseline. Jesse's regional multipliers handle geographic spread. Revisit after 60 days with real data.

### Remaining Punch List (Jesse)
1. Auto-fill on company settings doesn't save
2. Sign-up confirmation / onboarding email
3. Minor alignment cleanup (minimal)

---

## What's Next (Priority Order)

### Phase 1: Quality Tiers for Fixtures (Week 2-3)
Add basic/mid/premium selection for fixture items. Flooring already has this pattern (carpet builder/mid/premium grade).

Applies to: plumbing fixtures (faucets, toilets, sinks, disposals, water heaters), electrical fixtures (panels, fans, light fixtures), HVAC units (standard/high-efficiency already exists).

Each tier maps to a different BigBox price bracket. Schema should support tiers from day one even if UI ships later.

### Phase 2: InstaBid 411 — Voice Estimating (2 Days from Ready)
Phone-based AI voice estimator. Contractor calls a toll-free number from the job site, describes the project out loud, AI asks smart trade-specific questions, generates the full estimate — PDF, contract, Stripe deposit link — delivered to the homeowner's inbox before the contractor reaches his truck.

**Stack:** Vapi + Twilio toll-free number + Node webhook
**Status:** Kitchen plumbing demo working (Estimate #67, $2,149, all 4 items itemized). Field translation fix shipped. Staging environment live.
**Pricing:** Add-on feature, separate from base subscription. Value justifies significant premium — nothing like this exists in the market.

### Phase 3: Remodel Projects (Job Wrapper)
Remodels (kitchen, bath, addition) aren't a new trade — they're a project type that wraps multiple trades into one quote. A kitchen remodel combines plumbing + electrical + flooring + drywall + painting into a single customer-facing estimate.

Requires: Job wrapper object linking multiple trade-estimates, new pricing categories (cabinetry per LF by grade, countertops per sqft by material, appliance hookups), custom fields for contractor-defined line items.

Documentation exists (Manus docs covering kitchen/bath/addition inventories).

### Phase 4: Tier-3 AI Pricing Lookup
Real-time AI pricing for items not in the contractor's pricebook or platform defaults. The genuinely new capability. AI searches for current pricing, returns a result with confidence level, and writes it back to the platform defaults — self-learning catalog. Every lookup makes the system smarter.

### Phase 5: Manufacturer Sponsorship Integration
Native product placement at the moment of specification. When the estimator selects a faucet, the default is the sponsor's product (Kohler, Moen, etc.). Triple revenue: InstaBid subscription + sponsor placement fees + live install data value to manufacturers.

Targets: Kohler, Kraftmaid, Dal Tile, Panasonic, Cambria. John has personal contacts. Not pitching until product is solid.

---

## Distribution

### Primary: Around The House Radio Show
Co-hosted home improvement radio show reaching 1M+ weekly listeners across 200+ stations. InstaBid's primary launch and marketing channel. "As heard on Around The House with Eric G."

### Secondary: GC Distribution Playbook
Target respected general contractors who pull dozens of subcontractors onto the platform behind them. "Land 1 GC, get 12 subs." Ryan at REF Construction in Portland is the template — long-time GC, deeply respected, tons of sub-contractors.

### Tertiary: WebPrinter (Automated Outreach)
Separate tool that scrapes contractor businesses with weak websites, generates personalized demo sites with InstaBid already embedded, and enrolls contractors in email sequences. Drives trial signups. Not part of the Rails app — independent marketing pipeline.

### Warm Lead: Synchrony Financial
Patrice Boone (SVP & CMO) wants "another conversation." Synchrony has 45,000 contractors in their home repair financing network. InstaBid produces exactly the cost data Synchrony needs for better underwriting. Partnership = instant credibility + scale + zero-CAC distribution. Not pursuing until pricing pipeline and remodel demo are solid.

---

## Tech Stack

| Component | Technology | Owner |
|-----------|-----------|-------|
| Web app (production) | Rails 8.1.2, Ruby 4.0.1, Postgres, Tailwind | Jesse |
| Web app (legacy) | Node.js, HTML/JS | John (maintenance only) |
| Voice AI (411) | Vapi, Twilio, Node webhook on Railway | Todd |
| Pricing pipeline | Rails sandbox, BigBox API, Solid Queue | Todd → Jesse handoff |
| Lead gen (WebPrinter) | WordPress Multisite, Cloudways, n8n, Apollo | Separate system |
| Payments | Stripe | Integrated |
| Calendar | Google Calendar API | Integrated |
| Hosting | Railway (backend), Cloudways (WordPress) | — |
| Agent orchestration | Paperclip (local) | John |

---

## Business Model

**North star metric:** Subscriber count

**Current target:** 1,000 GCs at $499/month > 5,000 solo contractors at $99/month

**Revenue streams (current):** Monthly subscriptions (Starter/Pro/Business/Enterprise)

**Revenue streams (future):** 411 voice add-on, manufacturer sponsorship placements, data licensing (Synchrony-type partnerships), WebPrinter white-label agency product

**Exit target:** $25M within ~2 years

---

## Locked Decisions (Do Not Re-litigate)

- 411 is a feature on InstaBid, not a separate product
- Voice = front door to existing estimating engine, not a parallel engine
- All new backend work targets Jesse's Rails app. Node is maintenance-only
- Build first, pitch second — one shot at flood gates
- Basic/mid/premium pricing tiers from day one
- BigBox Collections (webhook push) over on-demand API calls
- Remodel = project_type wrapping multiple trades, NOT a new trade
- Staging protects production — no direct production deploys
- Never push to Jesse's main branch
- Default_pricings values are material+labor bundled for fixture items
- Road A for regional pricing: national baseline + Jesse's existing multipliers. Revisit after 60 days of data.

---

*Last updated: April 19, 2026*
*Author: John Dudley, with operational input from the entire Team Platypus crew*
