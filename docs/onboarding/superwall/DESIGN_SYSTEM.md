# Aura · Onboarding Design System (HTML / CSS)

Purpose: rebuild Aura's shipped visual language in **HTML/CSS** for the Superwall onboarding + paywall funnel. Every value below is the real value from the live iOS app (extracted from the Apps, Stats, and Profile screens plus the shared design system). Build the funnel to look like it was cut from the same app.

Read this with `ONBOARDING_MASTER_PROMPT.md` · that doc is the screen-by-screen spec; this doc is how everything looks.

---

## 0. Foundations

- **Platform:** mobile web, portrait only. Design on a **390px** artboard (iPhone), center the funnel in a `max-width: 430px` column. Use `rem`, `%`, `svh` units; never fixed desktop widths.
- **Surface: light.** Aura is a LIGHT app · an off-white ground, near-black text, blue accents, a friendly fox mascot. Do **not** build a dark funnel. (The paywall may sit on a blue field; everything else is light.)
- **One family: Rubik** (variable weight). Load from Google Fonts: `Rubik:wght@400;500;600;700;800;900`. There is no second font · headings and body are both Rubik, separated by weight.
- **Corners are always rounded** and should read as continuous/superellipse. Use the radius scale in §4.
- **Motion is soft and springy.** Every tappable element bounces slightly on press (§8). No linear UI transitions.
- **Never use em-dashes** anywhere (product rule + humanizer). Use periods, commas, or parentheses.

---

## 1. Color tokens

```css
:root {
  /* Brand / blue */
  --blue:            #2586FF;  /* primary: CTAs, fox chat bubble, Profile band, selected */
  --blue-shade:      #1C69D6;  /* darker "drop lip" under blue buttons */
  --blue-wash:       #DCEBFF;  /* pale panels, selected-tile fill */
  --blue-wash-shade: #BDD2F2;
  --blue-light:      #8FC2FF;
  --avatar-blue:     #CDEBFF;  /* soft disc behind an avatar / sticker */
  --selected-tint:   #9BD8FF;
  --signal-unlock:   #00BFFF;  /* earn / unlock GLOW only · countdowns, pulses. use sparingly */

  /* Grounds */
  --ground:          #FAFAFA;  /* app ground + sheet surface (off-white so white cards pop) */
  --surface:         #EEEDF0;  /* light-lavender full-screen ground (alt) */
  --field:           #F4F4F5;  /* recessed surfaces: inputs, tiles, trays */
  --field-stroke:    #E6E6E9;
  --field-shade:     #DCDCE1;
  --field-deep:      #E1E1E8;
  --track:           #ECECEE;  /* control / segment tracks */
  --divider:         #EDEDF1;

  /* Text */
  --title:           #1C1C1E;  /* near-black: titles, row labels */
  --subtitle-dark:   #3A3A3D;  /* card subtitles, values */
  --control-idle:    #767676;  /* idle labels, sub-labels (AA floor on white) */
  --subtitle:        #9B9BA3;  /* light grey subtitle */
  --badge:           #B8B8BE;

  /* Accents */
  --orange:          #FF6B03;  --orange-shade: #D15702;
  --green:           #34C77B;  --green-shade:  #25A160;
  --gain:            #21C55E;  /* positive gain / charge-bar fill */
  --caution:         #E8A33D;

  /* Danger */
  --danger:          #F0453E;
  --red:             #FF3B30;  --red-shade:    #CC2F26;  /* "Tempting"/destructive CTA */
  --warning:         #DF152D;

  /* Purple (used on Profile feedback card) */
  --purple:          #6D5CE0;

  /* Lane colors (product's three app buckets) */
  --lane-forbidden:  #16151C;  /* cold near-black */
  --lane-tempting:   #FF3B30;  /* deep red */
  --lane-allowed:    #2586FF;  /* = blue */

  /* Frozen / ice (the Blocks piece · use only when showing frozen apps) */
  --frost:           #BEE6FA;
  --frost-glaze:     #EAF8FF;

  /* Translucent helpers */
  --chrome-on-light: rgba(0,0,0,.08);  /* small floating chrome disc on light */
  --scrim-on-color:  rgba(0,0,0,.16);  /* panel on a colored surface */
  --on-color-2ndary: rgba(255,255,255,.85); /* secondary text on color/dark */
}
```

**Rules of thumb**

- Body text on the light ground = `--title` (#1C1C1E). Secondary = `--control-idle`. Never grey-on-grey below `--control-idle` for anything a user must read.
- `--blue` is the one hero accent. Resist adding new colors; use the ones above.
- `--signal-unlock` (#00BFFF) is a **glow**, not a fill · reserved for earn/unlock moments (a countdown, a pulse). Don't paint big areas with it.
- The paywall may use a **blue field** (`--blue` → a slightly darker blue gradient) with white text; that is the one screen family allowed to invert to color-on-dark-ish.

### Card gradient pairs (top → bottom)

Special cards use a two-stop vertical gradient (`lighter → base`). Recipe: `linear-gradient(180deg, color-mix(in srgb, BASE 88%, white) 0%, BASE 100%)` (that ~12% lightening matches the app's `lightened(by: 0.12)`).

| Card meaning | Base |
|---|---|
| Allowed / primary | `--blue` |
| Tempting / warning | `--red` |
| Feedback / founders | `--purple` #6D5CE0 |
| Cost "coins earned" gold | #E8A317 → #B26A00 |
| Streak | #FF7A33 → #D0491A |
| Focus red | #C8324A → #8A1B2E |

---

## 2. Typography

**Family:** Rubik, variable weight. Weights used: 400 regular, 500 medium (body default), 600 semibold, **700 bold (the normal ceiling)**, 900 black (**only** for stroked/outlined numbers).

### Type scale

| Role | px | weight | use |
|---|---|---|---|
| `hero` | **34** | 700 (or 900 when stroked) | full-screen headline; big screen titles; the user's name |
| `title` | 22 | 700 | sheet / section title |
| `banner` | 20 | 700 | a full-width sentence sitting on a field; card titles |
| `cta` | **18** | 700 | primary button label |
| `section` | 15–20 | 700 | group heading (15 in lists, 20 as a screen section head) |
| `card-title` | 15 | 600 | multi-line card title |
| `body` | 15 | 500 | default running text |
| `subtitle` | 13 | 400–500 | line under a title |
| `card-blurb` | 13 | 400 | explanatory line inside a card |
| `label` | 13 | 600–700 | stat labels, chip labels |
| `sub-label` | 12 | 500 | smallest supporting text |
| `chat` | **17** | 500 | chat-bubble message text |

Line-height: 1.25 for headings, 1.4 for body. Letter-spacing: default (no tight tracking on body).

### Stroked numbers (the signature number treatment)

Big numbers · the cost stats, the reclaimed total, hero counts · are drawn as **black fill with a white outline and a soft shadow**, in Rubik **900**. This is Aura's most recognizable type device. Reuse it for every dramatic number in the funnel (days/year, life-weeks, "back in control by", the type reveal metrics).

Web recipe (outline reads *outside* the glyph):
```css
.stroked-num {
  font: 900 34px/1 "Rubik", sans-serif;
  color: #000;
  -webkit-text-stroke: 6px #fff;   /* ~ 8.8% of size; app uses outlineWidth*2 */
  paint-order: stroke fill;         /* stroke first, fill on top */
  text-shadow: 0 2px 4px rgba(0,0,0,.30);
}
```
Outline ratio = **outline width ≈ 8.8% of font size** (3.0 at 34px, doubled for the stroke pass). At 30px use ~5.3px stroke (2.6 ratio) with `text-shadow: 0 2px 3px rgba(0,0,0,.25)`. On a colored background keep the same black-fill/white-outline; it holds up.

---

## 3. Spacing scale (4pt grid)

```css
--xs: 4px;  --s: 8px;  --m: 12px;  --l: 16px;  --xl: 24px;  --xxl: 32px;  --xxxl: 48px;
```
Screen horizontal padding = `--xl` (24). Gap between stacked blocks = `--m` (12) to `--l` (16). Bottom safe area for a persistent CTA ≈ 92px of clearance above the very bottom on tall content.

---

## 4. Radii

```css
--r-micro: 6px; --r-tile: 8px; --r-field: 12px; --r-card: 16px;
--r-hero: 24px;  --r-panel: 32px; --r-sheet: 38px; --r-pill: 999px;
```
Nest smaller radii inside larger (a 12 field inside a 16 card inside a 32 panel). Cards and chat bubbles use **24** (`--r-hero`). Option rows use **16**. Pills/buttons use **999**. Achievement-style cards use **28**. Prefer a superellipse look; if you can, apply a subtle `border-radius` + no harsh corners.

---

## 5. Shadows / elevation

The app's signature is a **double shadow** on floating cards · a soft ambient plus a tight contact · which gives the "chunky game piece" lift. Use it on every hero card (cost cards, plan cards, the type-reveal card, paywall plan cards).

```css
--card-shadow: 0 11px 20px rgba(0,0,0,.16), 0 2px 4px rgba(0,0,0,.10);
--fab-shadow:  0 3px 8px rgba(0,0,0,.25);
--chrome-shadow: 0 2px 6px rgba(0,0,0,.06);
--fox-shadow:  0 5px 10px rgba(0,0,0,.12);  /* soft ground under fox art */
```
Small floating circular chrome (a close ×, a back chip): `--chrome-shadow`. The fox art sits on `--fox-shadow` (a soft blurred oval), never a hard drop.

---

## 6. Component recipes

### 6.1 Primary button (the drop-lip pill) · the main CTA

A capsule with a darker "shade" behind it and a lighter "face" sitting a few px above the bottom, so it looks like a physical key you press down. Height **56**, label Rubik **18/700**.

```html
<button class="btn btn--blue">Continue</button>
```
```css
.btn {
  position: relative; height: 56px; width: 100%;
  border: 0; border-radius: 999px; cursor: pointer;
  font: 700 18px "Rubik"; color: #fff;
  background: var(--shade);                 /* the drop lip */
}
.btn > span, .btn { display: grid; place-items: center; }
.btn::before {                              /* the face, 5px above bottom */
  content: ""; position: absolute; inset: 0 0 5px 0;
  border-radius: 999px; background: var(--face); z-index: 0;
}
.btn > * { position: relative; z-index: 1; }
.btn:active { transform: scale(.96); }
.btn:active::before { inset: 5px 0 0 0; }    /* face sinks on press */
.btn { transition: transform .16s cubic-bezier(.2,.8,.2,1); }
.btn--blue   { --face:#2586FF; --shade:#1C69D6; }
.btn--orange { --face:#FF6B03; --shade:#D15702; }
.btn--green  { --face:#34C77B; --shade:#25A160; }
.btn--red    { --face:#FF3B30; --shade:#CC2F26; }
.btn--white  { --face:#FFFFFF; --shade:rgba(0,0,0,.14); color:#1C1C1E; }
```
Disabled: `opacity:.45`. There is only **one** primary CTA per screen; a secondary action (e.g. "no thanks") is a plain text button in `--control-idle`.

### 6.2 Option row (the workhorse selectable)

Full-width rounded row: optional left icon/emoji, bold label, optional right meta. Idle = `--field`; **selected = `--blue-wash` fill + 2px `--blue` border + blue label**. Single-select advances; multi-select shows a check.

```css
.opt {
  display:flex; align-items:center; gap:var(--m);
  width:100%; padding:16px var(--l); border-radius:var(--r-card);
  background:var(--field); border:2px solid transparent; color:var(--title);
  font:700 16px "Rubik"; text-align:left;
}
.opt .meta { margin-left:auto; color:var(--control-idle); font-weight:500; font-size:13px; }
.opt[aria-selected="true"] {
  background:var(--blue-wash); border-color:var(--blue); color:var(--blue);
}
.opt:active { transform:scale(.98); }
```
Rows are stacked with a `--m` (12) gap. Icons/emoji at 22–26px on the left.

### 6.3 Fox + speech bubble (statement / question header)

The recurring "voice" device. Fox art bottom/left-ish, a rounded bubble to its side with the line. On a **light** ground the bubble is white/`--field` with dark text and a hairline; the tail points at the fox.

```css
.fox-say { display:flex; align-items:flex-end; gap:var(--s); }
.fox-say img.fox { width:96px; height:auto; filter: drop-shadow(0 5px 10px rgba(0,0,0,.12)); }
.bubble {
  background:#fff; color:var(--title); font:600 16px/1.35 "Rubik";
  padding:14px 16px; border-radius:var(--r-hero); border:1px solid var(--divider);
  box-shadow: var(--chrome-shadow); max-width:70%;
}
```

### 6.4 Chat thread (fox diagnosis)

Reuses Aura's intervention thread. **Fox (incoming) bubble = solid `--blue`, white text, radius 24, 17/500, left-aligned.** **User (reply) bubbles on the light ground = `--field` with `--title` text (or white), right-aligned** · the app's own version is dark glass over a photo, but on the funnel's light ground use `--field`/white so it reads. Messages type in sequentially with a **typing indicator** first.

```css
.msg { max-width:78%; padding:12px 16px; border-radius:24px; font:500 17px/1.35 "Rubik"; }
.msg--fox  { background:var(--blue); color:#fff; align-self:flex-start; border-bottom-left-radius:8px; }
.msg--user { background:var(--field); color:var(--title); align-self:flex-end; border-bottom-right-radius:8px; }
/* typing dots: 3 white circles, 7px, 5px gap, cycle every 280ms */
.typing { display:inline-flex; gap:5px; padding:12px 16px; background:var(--blue); border-radius:24px; }
.typing i { width:7px; height:7px; border-radius:50%; background:#fff; opacity:.35; animation:blink 840ms infinite; }
.typing i:nth-child(2){ animation-delay:.28s } .typing i:nth-child(3){ animation-delay:.56s }
@keyframes blink { 0%,60%,100%{opacity:.35} 30%{opacity:1} }
```
Reply choices render as **white pills with blue text** (`--blue`, 17/600) that the user taps to "send". Fox "typing" delay ≈ `min(1400, 420 + text.length*22)` ms before each message.

Fox avatar in the header: the Aura app icon, 64px, circle-clipped, 1px `--divider` ring. Name pill: "Aura".

### 6.5 Hero card (cost / plan / type reveal)

A `--r-hero` (24) card with a gradient fill (§1), `--card-shadow`, white text, optional corner art that **bleeds off the bottom-trailing corner** and a faint **corner sunburst/rings** behind it. Content clipped to the radius.

- Sunburst (on blue/allowed): 40 alternating `rgba(255,255,255,.24)`/transparent angular rays from the bottom-right corner, radially masked so it fades out by ~210px.
- Rings (on dark/red): 9–10 concentric `rgba(255,255,255,.06–.10)` bands from the same corner.
- Corner art (fox / icon) sits bottom-right, ~130–142px, bleeding past the edge; keep text clear with a trailing inset (~132px).

CSS approximation of the sunburst:
```css
.sunburst {
  position:absolute; inset:0;
  background: repeating-conic-gradient(from 0deg at 100% 100%,
    rgba(255,255,255,.24) 0 4.5deg, transparent 4.5deg 9deg);
  -webkit-mask: radial-gradient(210px at 100% 100%, #000 40%, transparent 100%);
  mask: radial-gradient(210px at 100% 100%, #000 40%, transparent 100%);
}
```

### 6.6 Life grid (the cost visualization)

A grid of small rounded squares/dots = a life in weeks (or years). Fill obligations first in muted tones, reveal remaining "free" cells, then turn the scrolling share **red**. Reuse the **same grid** for loss and (later) recovery.

```css
.grid { display:grid; grid-template-columns:repeat(18, 1fr); gap:4px; }
.grid i { aspect-ratio:1; border-radius:3px; background:var(--field); }
.grid i.spent { background:var(--red); }       /* scrolling */
.grid i.free  { background:var(--gain); }       /* reclaimable */
```
Animate cells filling in sequence (stagger ~15–25ms each). Numbers below the grid use the **stroked-number** treatment.

### 6.7 Paywall plan card

Selectable plan rows on a blue field. Selected = white/near-white fill with `--blue` border + check; unselected = translucent white outline. A `MOST POPULAR` badge sits on the anchor plan. Price shown large; per-week reframing small beneath. CTA = the drop-lip pill (white on blue field, or `--green`).

### 6.8 Progress bar

Thin top progress bar on the **question/diagnosis stretch only** (hidden on splash, immersive cost beats, ritual, and paywall). Track `--track`, fill `--blue`, height 6px, radius 999. A back chevron sits at the top-left on reversible screens.

```css
.progress { height:6px; background:var(--track); border-radius:999px; }
.progress > span { display:block; height:100%; background:var(--blue); border-radius:999px; transition:width .3s ease; }
```

### 6.9 Text input

Recessed `--field` capsule/rounded field, `--field-stroke` 1px border, `--title` text at 17px, generous 16px padding. Label above in `--title` 15/600. Focus: border → `--blue`.

---

## 7. Layout archetypes (referenced by the master prompt as A–F)

- **A · Splash.** Full-bleed, brand mark / fox animation centered, wordmark low. No chrome.
- **B · Fox bubble + option rows + CTA.** Progress bar + back at top; fox+bubble poses the question; 2–6 option rows; persistent drop-lip CTA at the bottom (disabled until a choice).
- **C · Fox bubble statement + art + CTA.** One idea, fox reacts, generous negative space, single CTA.
- **D · Two/choice cards.** Big cards with icon + title + subtitle; optional `RECOMMENDED` badge; or a red/blue toggle for the two-path contrast.
- **E · Full-screen stat / interactive.** One number or one interaction (drag slider, life grid, loading theater). Stroked numbers. Often no progress bar.
- **F · Paywall.** Blue field, plan cards, `MOST POPULAR`, benefit checklist, drop-lip CTA + plain-text secondary ("no thanks"), fine print.

---

## 8. Motion

- **Press bounce** on every tappable card/row/pill: `transform: scale(.96)` on press, release with a spring feel · `cubic-bezier(.2,.8,.25,1)`, ~280ms. Buttons also sink their "face" (§6.1).
- **Screen transitions:** forward = slide/fade up-and-in (~250ms ease-out); back = reverse. Keep spatial continuity.
- **Reveals:** stat numbers count up; grid cells stagger in; loading "theater" resolves checklist items one by one. Exit animations shorter than enter (~60–70%).
- **Reduced motion:** respect `prefers-reduced-motion` · drop the count-ups, staggers, and parallax; keep instant states.
- Springs to match the app: card/press ≈ `response .28, damping .55`; button ≈ `response .24, damping .55`. In CSS, approximate with the easing above and 220–300ms.

---

## 9. Do / don't

- **Do** keep it light, blue, rounded, and chunky. One accent (blue). One font (Rubik). Big rounded cards with the double shadow. Stroked numbers for drama.
- **Do** let the fox carry the voice via bubbles and the chat.
- **Don't** build a dark, neon, or "premium frozen glass" funnel · the ice/frost is only for showing *frozen apps*, not the whole UI.
- **Don't** add gradients or glows that aren't in this doc. No em-dashes. No emoji outside the fox's own lines.
