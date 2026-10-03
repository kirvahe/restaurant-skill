# Guía Repsol

Spain's national restaurant guide. Access spec, filter vocabulary, and trust guardrails.

*Compiled 2026-07-28. All endpoints, parameters, and URL patterns below were verified by live request. Anything unverified is marked ⚠️.*

## Contents
- Why this source exists in the skill
- Two award systems — do not conflate (Soles vs Soletes, criteria, thematic editions)
- Access — API (primary path): endpoints, two-step lookup, `POST /poi/map` body, no pagination, `GET /poi/{id}`
- Filter vocabulary (`GET /explore/tags`): `calificacion;`, `tipoEstablecimiento;`, `tipoCocinaRte;`, `servicios;`, `cocineros;`, `famosos;`, `rango;`, verified filter results
- URL patterns (HTML side — fetch with Firecrawl)
- Per-venue fields — API vs HTML
- Search fallback (when Bash/curl is unavailable, or the API changes)
- Editorial sections worth reading
- Geographic coverage (incl. the Andorra location trap)
- Guardrails — apply all three; honest caveats on the source itself

## Why this source exists in the skill

Repsol rates categories Michelin does not touch at all — chiringuitos, heladerías, market stalls, vinotecas, coctelerías, *fast good*, sidrerías — and it rescues Spanish classics Michelin persistently ignores (Lera, Sacha, Horcher, La Tasquita, Los Marinos José hold Soles but never a star).

Chefs use it as a working instrument, not just an honour. Begoña Rodrigo: *"un Solete es una pista maravillosa, que te asegura salir contento cuando vas a parar en una zona que no conoces."* Elena Arzak: *"sitios... a los que nosotros mismos acudimos."*

This makes it the strongest available machine-readable source for the **casual layer** — exactly where Michelin is blind and Google Maps is tourist-noisy.

---

## Two award systems — do not conflate

| | Soles | Soletes |
|---|---|---|
| API filter | `calificacion;1` / `;2` / `;3` / `;R` | `calificacion;S` |
| URL path | `/es/fichas/restaurante/` | `/es/fichas/solete/` |
| Tiers | 3 / 2 / 1 Soles + "Restaurante Guía Repsol" (renamed from "Recomendado" in 2026) | Flat, no tiers |
| Total | 808 restaurants (2026 edition) | >5,000 (14th ed.); ~5,500+ as of Jun 2026 |
| New in 2026 | 83 = 3 Tres + 11 Dos + 69 Un Sol | ~250–300 per edition |
| Cadence | Annual, one gala (2026: Tarragona, 16 Feb). Archive 2018–2026 | 2–4 editions/year, numbered (8th…14th) |

**Criteria, quoted from the site:**
- Solete: *"Un placer asequible, donde prima la calidad y el buen hacer… Para repetir por su ambiente informal y acogedor."*
- 1 Sol: *"Justifica hacer kilómetros o parar a conocerlo en medio de un viaje."*
- 2 Soles: *"Merece los muchos kilómetros recorridos."*
- 3 Soles: *"Es el destino final del viaje."*

Note the award definitions are explicitly road-framed — the guide descends from the 1979 Campsa *Guía del Viajero*. Countervailing urban editions exist ("Soletes en el centro", 359 venues in provincial capitals; "Soletes de barrio").

**Thematic / seasonal Solete editions** (all verified live): `soletes-de-verano-2025` · `soletes-navidad-guia-repsol` · `soletes-para-exprimir-la-primavera` · `soletes-guia-repsol-de-barrio` · `soletes-de-carretera` · `soletes-guia-repsol-centro-ciudad` · Soletes de los Cocineros · `soletes-favoritos-famosos` · `soletes-verano-portugal-2026`

---

## Access — API (primary path)

**Base:** `https://guia-app-api.cloudapp.repsol.com`
**Auth: none.** No key, no token, no cookie.

```
currentSite: es          # or "pt" for Portugal — REQUIRED
Content-type: application/json; charset=UTF-8
```

The API host is **not** behind Akamai — plain `curl` works. `www.guiarepsol.com` **is** Akamai-protected: plain curl and WebFetch both get 403, including `/robots.txt` and `/sitemap.xml`. Use Firecrawl for any HTML page.

Because `POST /poi/map` is a POST, the standard scrape/fetch tools (`mcp__firecrawl__firecrawl_scrape`, `mcp__exa__web_fetch_exa`, built-in WebFetch) cannot reach it — they issue GET. The API path requires Bash + curl; the examples below pipe the JSON through `jq`. When Bash is unavailable, fall back to the search path below.

### Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/search/{searchTerm}` | Resolve city → `locationId`; predictive, max 3 per category |
| POST | `/poi/map` | **The venue listing endpoint** |
| GET | `/poi/{id}` | Venue detail + live open/closed |
| GET | `/explore/tags` | Full filter vocabulary |
| POST | `/search/detail/lists` | Editorial articles only — **not venues** |
| POST | `/search/detail/carrousels` | Article carousels |

`searchTerm` is a **path segment, not a query param**. `/search?q=madrid` returns `"0 resultados para 'undefined'"`.

### Two-step lookup — the standard call

```bash
# STEP 1 — city name → locationId (a Google Place ID)
curl -s -H "currentSite: es" \
  "https://guia-app-api.cloudapp.repsol.com/search/San%20Sebastian" \
  | jq -r '.locations.data[0].id'
# → ChIJFf5oO_6vUQ0RSUaGlFnFPuQ

# STEP 2 — locationId + filters → venues
curl -s -X POST "https://guia-app-api.cloudapp.repsol.com/poi/map" \
  -H "Content-type: application/json; charset=UTF-8" \
  -H "currentSite: es" \
  -d '{"tagIds":["calificacion;S"],"locationId":"ChIJFf5oO_6vUQ0RSUaGlFnFPuQ"}' | jq -r '.poisMap[] | "\(.name) | \(.location) | \(.canonical)"'
```

⚠️ **The response key is `poisMap`, not `data`.** `POST /poi/map` returns `{"poisMap":[...], "viewport":{...}}`; each entry carries `name`, `location`, `calification`, `canonical` and `id`. A `.data[]` jq filter silently yields nothing and reads exactly like "this city has no venues of that type" — which is how a whole search can be abandoned on a filter typo. `GET /search/{city}` is the one that uses `.locations.data[0].id`; the two endpoints do not share a shape. *(Verified September 2026.)*

### `POST /poi/map` request body

```jsonc
{
  "tagIds":     ["calificacion;S"],          // array, may be []
  "locationId": "ChIJ...",                   // REQUIRED — omit → 400
  "viewport":   {                            // OPTIONAL, widens beyond default 30
    "northeast": {"latitude": 40.47, "longitude": -3.65},
    "southwest": {"latitude": 40.38, "longitude": -3.75}
  },
  "coordinate": {"latitude": 0, "longitude": 0},  // optional
  "searchTerm": "...",                            // optional
  "poiType":    "gastronomia"                     // optional
}
```

Response: `{"viewport": {...}, "poisMap": [...]}`. Item shape:

```json
{"id":"62722","type":"gastronomia","isStop":false,
 "coordinate":{"latitude":40.4171724,"longitude":-3.704593},
 "name":"Casa Labra","canonical":"/es/fichas/solete/casa-labra-62722/",
 "image":"/content/dam/...","location":"Madrid, Madrid",
 "calification":"S","establishmentType":"2"}
```

Prefix `canonical` with `https://www.guiarepsol.com` to get a working URL.

### ⚠️ There is no pagination — results are zoom-clustered

A wider viewport returns **fewer** results, not more. Verified against the Madrid `locationId`:

| Query | n |
|---|---|
| locationId only, no viewport | 30 |
| + Madrid-city viewport, no tags | 70 |
| + viewport 40.30/-3.90 → 40.60/-3.50, `calificacion;S` | 40 |
| + viewport 35/-10 → 44/4.5 (all Spain), `calificacion;S` | 29 |

Combining award tiers also truncates: `["1","2","3"]` returns 32, but queried individually 3→6, 2→25, 1→28, R→42 (101 total).

**Rules that follow:** query one `calificacion` tier at a time, and tile small viewports to enumerate an area. Never assume a single call returned everything.

### `GET /poi/{id}` — venue detail

```json
{"id":"62722","title":"Casa Labra","subtitle":"Bar",
 "icon":{"description":"Solete · €"},
 "canonicalWeb":"https://www.guiarepsol.com/es/fichas/solete/casa-labra-62722/",
 "coordinate":{"latitude":40.4171724,"longitude":-3.704593},
 "schedule":{"isOpen":false,"nextScheduleStep":"Abre a las 11:30",
             "businessStatus":"OPERATIONAL"},
 "address":"C. de Tetuán, 12, Centro, 28013 Madrid",
 "phoneNumber":"915310081","location":"Madrid, España"}
```

`schedule.businessStatus` is the live open/closed check — use it to satisfy the skill's verify-open-status rule at zero extra cost.

---

## Filter vocabulary (`GET /explore/tags`)

Syntax is `prefix;value` — semicolon separator, literal accented Spanish, no URL-encoding inside JSON.

**`calificacion;` — Categoría**
```
calificacion;S   Solete
calificacion;R   Restaurante Guía Repsol
calificacion;1   1 Sol
calificacion;2   2 Soles
calificacion;3   3 Soles
```

**`tipoEstablecimiento;` — Tipo de local** (id ≠ display label)
```
tipoEstablecimiento;Restaurante
tipoEstablecimiento;Fast good
tipoEstablecimiento;Chiringuitos y terrazas
tipoEstablecimiento;Bares, tascas y barras
tipoEstablecimiento;Cafeterías y pastelerías
tipoEstablecimiento;Heladerías
tipoEstablecimiento;Vinotecas, bodegas y sidrerías
```

**`tipoCocinaRte;` — Comida** (28 values)
```
Española · Mercado · Creativa · Mediterránea · Marinera · Andaluza · Asiática
Carnes · Gallega · Asturiana · Canaria · Vegetariana · Italiana · Peruana
Francesa · Africana · Árabe · Casera · Europea · Griega · Hebrea
Internacional · Latinoamericana · Mexicana · Norteamericana · Portuguesa
```
Plus `especialidad;Arroz` → "Arroces". ⚠️ `tipoRestaurante;Tapas   Pintxos` carries a literal triple space and returned 0 results — treat as broken, do not use.

⚠️ **The vocabulary is case- and accent-sensitive, and it is coarser than it looks.** `tipoCocinaRte;japonesa` returns 0 results — there is no Japanese tag at all. Every Japanese, Chinese, Korean, Thai, Vietnamese and Indian venue collapses into the single `tipoCocinaRte;Asiática` bucket, capital A and accent required. The same holds for the rest of the list: pass the value exactly as printed above. When a cuisine has no tag of its own, filter by `Asiática` (or the nearest bucket) and narrow by name and by scraping the `canonical` pages — the API cannot do it for you. *(Verified September 2026 against the Madrid `locationId`.)*

**`servicios;` — Espacio y servicios**
```
servicios;terraza_verano    Con terraza
servicios;conVistas         Con vistas
servicios;acepta_mascotas   Con mascotas
servicios;conNinnos         Con niños      (double-n typo is real — copy it exactly)
```

**`cocineros;{Chef Name}`** — 125 chefs. Group id `cocineros;all`. E.g. `cocineros;Elena Arzak`, `cocineros;Andoni Luis Aduriz`, `cocineros;Angel León`, `cocineros;Diego Guerrero`.

**`famosos;{Name}`** — 69 celebrities. Group id `famosos;all`. ← lowest-trust dimension, see Guardrails.

**`rango;` — Precio.** ⚠️ **Appears to be a no-op.** `calificacion;S` alone in Madrid returned 68; adding `rango;Menos de 35€` returned the same 68. Do not rely on it — filter price from the ficha instead.

### Verified filter results (Madrid locationId + city viewport)

| tagIds | n |
|---|---|
| `[]` | 70 |
| `calificacion;S` | 68 |
| `calificacion;S` + `tipoEstablecimiento;Bares, tascas y barras` | 36 |
| `calificacion;S` + `tipoEstablecimiento;Vinotecas, bodegas y sidrerías` | 24 |
| `calificacion;S` + `servicios;acepta_mascotas` | 34 |
| `calificacion;S` + `servicios;terraza_verano` | 26 |
| `calificacion;3` | 6 |

---

## URL patterns (HTML side — fetch with Firecrawl)

Pagination is universal: append `/page/N/`.

| Purpose | Template | Constructible from a city name? |
|---|---|---|
| Venue (Sol) | `/es/fichas/restaurante/{slug}-{id}/` | No — needs ID |
| Venue (Solete) | `/es/fichas/solete/{slug}-{id}/` | No — needs ID |
| Soletes by comunidad | `/es/soletes/listado-completo/{comunidad}/` | Yes |
| Soletes by category | `/es/soletes/{categoria}/` — `/bares/`, `/cafeterias/`, `/fast-food/`, `/vinotecas-y-bodegas/` | Yes |
| City eat/drink hub | `/es/{city}/comer-y-beber/` | **Only madrid, barcelona, sevilla, valencia** |
| City Soletes list | `/es/{city}/comer-y-beber/soletes/` | **Madrid only** |
| Soles hub | `/es/comer/soles-repsol/` | Yes |
| Soles by year | `/es/soles-repsol/soles-{year}/` (2018–2026) | Yes |
| Methodology | `/es/soles-repsol/como-se-otorgan-los-soles-guia-repsol/` | n/a |

**Only the numeric ID matters in a ficha URL.** Verified: `/es/fichas/restaurante/zzz-62722/` returns 200 and redirects to the canonical `/es/fichas/solete/casa-labra-62722/`. The type segment and slug are cosmetic — store IDs, not slugs.

**You cannot build a ficha URL from a restaurant name.** The ID must come from the API or from search.

**Verified 404s — do not guess these:** `/es/barcelona/comer-y-beber/soletes/` (the pattern is Madrid-only), `/es/tag/provincia-guipuzcoa/` (while `provincia-sevilla` works).

Comunidad slugs verified from live links: `comunidad-de-madrid`, `catalunya`, `comunidad-valenciana`, `extremadura`, `euskadi`. ⚠️ The other 12 were not individually verified — enumerate from `/es/soletes/listado-completo/` before hardcoding.

⚠️ Never scrape `/es/buscador/` or the parent `/es/soletes/listado-completo/` — both are empty shells; the latter ships a literally empty `ItemList`. Search facets live in the URL **hash fragment** (`#q=`, `&f:@calificacion=[S]`), so they never reach the server and cannot be scraped.

Stack is Adobe AEM (server-rendered Java), not React/Next — there is no `__NEXT_DATA__`.

---

## Per-venue fields — API vs HTML

| Field | API | HTML ficha |
|---|---|---|
| Name, address, phone | ✅ | ✅ |
| **Coordinates** | ✅ | ❌ not in page HTML |
| **Live open/closed** | ✅ `schedule.businessStatus` | partial |
| **Full 7-day hours** | ❌ | ✅ |
| Award tier | ✅ `calification` | ✅ |
| Price band | ✅ `priceRange` (`E`/`EE`/`EEE`) via `/search` | ✅ |
| Editorial review text | ❌ | ✅ |
| Signature dishes | ❌ | ✅ ("Recomendación Guía Repsol") |
| **Award history timeline** | ❌ | ✅ ("2019 Recomendado · 2020 1 Sol · 2025 1 Sol") |
| Chef / sommelier / floor manager | ❌ | ✅ Soles fichas only |
| Website / Instagram, booking link | ❌ | ✅ |
| Dietary + services detail | ❌ | ✅ |

**Strategy: API for discovery, geo, and live status → Firecrawl the `canonical` URL for hours, review text, chef, and award history.**

---

## Search fallback (when Bash/curl is unavailable, or the API changes)

```
site:guiarepsol.com/es/fichas/solete {type} {city}       ← path-scoped = Soletes only
site:guiarepsol.com/es/fichas/restaurante {type} {city}  ← same for Soles
site:guiarepsol.com soletes {theme} {city}               ← surfaces thematic routes
mcp__firecrawl__firecrawl_map url=guiarepsol.com search="{terms}"   ← cheapest section enumeration
```

Verified: `site:guiarepsol.com/es/fichas/solete vinoteca Bilbao` returned 6 real Bilbao Solete fichas with addresses in the snippets.

⚠️ Plain `mcp__firecrawl__firecrawl_map` on the root is useless — 2,908 of 3,000 URLs were `/es/fichas/vino/` wine cards. Always pass `search=`.

---

## Editorial sections worth reading

- **`/es/comer/donde-comen-los-cocineros/`** — chefs naming their own favourite places, with `/{city}` variants. Highest-value section in the site; maps directly onto the skill's chef-cited [A] tier.
- `/es/comer/nuestros-favoritos/` — editorial reviews
- `/es/comer/de-tapeo/` · `/es/comer/vinos-y-bodegas/`
- `/es/viajar/con-mi-mascota/` — pet-friendly travel + food
- Named critics with bylines at `/es/autores/{slug}/`

Filler for this skill's purposes: `/es/comer/recetas/` (recipes), `/es/comer/en-el-mercado/` (producer profiles).

---

## Geographic coverage

Spain (`/es/`, all 50 provinces) · **Portugal** (`/pt/` — own Soles and Soletes, own gala, IDs prefixed `pt`, requires `currentSite: pt`) · **Andorra** (verified live venues).

Rural and roadside coverage is genuinely strong — verified Soletes in villages like Alloza, Alcorisa, Híjar, Mendaro. Dedicated highway pages exist (A-1, A-5, A-7). Catalonia leads the Soles count with 114 distinguished restaurants.

⚠️ **Location disambiguation trap.** `/search/andorra` returns as its first result `{"title":"Andorra","subtitle":"Localidad · España"}` — that is Andorra in **Teruel**, not the country, and `/poi/map` will then return Teruel villages. Always check `locations.data[].subtitle` before using an id.

---

## Guardrails — apply all three

**1. An award means "was once judged good", not "is currently good."**
Soles are rarely revoked except when a venue closes. Directo al Paladar (Mar 2025): the edition was built from **400 visits against a 618-venue list** — *"ni siquiera se han vuelto a visitar todos los establecimientos que aparecen en la guía"* — using 53 part-time inspectors. Michelin visits every listed restaurant at least once, up to eight times for three stars. Always confirm `schedule.businessStatus` from `GET /poi/{id}`.

**2. Inspector- and chef-sourced Soletes outrank celebrity-sourced.**
Celebrity Soletes are favourites named by public figures — a personal recommendation, not an inspection. Treat `famosos;` as the weakest dimension in the API, `cocineros;` as materially stronger, and standard inspector-awarded Soletes as stronger still.

**3. Volume is not endorsement strength — the badge is a filter, not a ranking.**
5,500+ Soletes and 808 soleados. Carlos Maribona (ABC) on the inflation: *"Un exceso que diluye la importancia de los galardonados. Poca gente conoce cuáles son los 42 restaurantes con tres soles."* Use the award to shortlist, then rank with the taste profile.

### Honest caveats on the source itself

- **No pay-to-play evidence was found, in either direction.** No source alleges venues pay for awards; no official denial exists either. Two real structural conflicts exist and must not be conflated with pay-to-play: Repsol sells restaurants a paid "Cocina Eficiente y Sostenible" certification (the pilot cohort was almost entirely already-soleado venues), and galas are co-funded by regional governments. No source links either to award outcomes.
- **Spanish press is not a neutral check here.** No critical piece was found in El Comidista or El País; El País live-streams the Soles gala on its own YouTube channel.
- ⚠️ **Unread source:** Berasaluce, *Relaciones de poder en la gastronomía española contemporánea* (Univ. de Cádiz, 2025), ch. 6.1, dataset of 6,093 recognitions 2011–2019. Extraction failed; findings unverified. Worth a manual read at pp. 179–200 if award-geography bias ever matters.
- ⚠️ **Conflicting counts.** Onda Cero reported "98 nuevos Soles… 16 con dos" for 2026 against guiarepsol.com's own "83 / 3 / 11 / 69". Trust the site's own figure.
