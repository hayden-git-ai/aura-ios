# Handoff 03 — Retire the old Slack reply path (§10)

**For:** GPT desktop (browser for the Slack admin UI + terminal for Supabase).
**Goal:** #support is now a **notify-only** feed. Founder replies go through Crisp
(`crisp-events`), so the old Slack → `slack-events` → app reply path is dead code
receiving live Slack traffic. Turn it off. Small task.

## Background (so you don't break the live path)

- **Live reply path (keep):** founder replies in **Crisp** → `crisp-events` → app.
  Do not touch this.
- **Retired path (kill):** Slack Event Subscriptions call `slack-events`, which
  matched `#support` thread replies back to a user. No longer used.
- `support-send` still posts a one-way heads-up into `#support` (channel
  `C0C0BCMJNUB`). That stays — it's just a notification, not a reply channel.

## Guardrail

Only disable the Slack **Event Subscriptions** and (optionally) delete the
`slack-events` function. Do **not** touch `support-send`, `crisp-events`, or any
Crisp config. If unsure, disable in Slack (reversible) and stop.

## Step A — Turn off Slack Event Subscriptions (required)

1. Go to https://api.slack.com/apps and open the Aura support app.
2. **Event Subscriptions** → toggle **Enable Events OFF** (or clear the Request
   URL that points at `.../functions/v1/slack-events`). Save.
3. That's the checklist item. Slack will stop calling `slack-events`.

## Step B — Delete the dead function (optional cleanup, recommended)

With Events off, `slack-events` is an unused public endpoint. Shrink the attack
surface by removing it. From `server/`:

```bash
supabase functions list                 # confirm slack-events is there
supabase functions delete slack-events  # removes the deployed function
```

Leave the source (`server/supabase/functions/slack-events/`) in the repo for
history, or delete it too if Hayden prefers a clean tree. Do **not** delete
`crisp-events` or `support-send`.

## Step C — Verify nothing broke

1. From the app, send a test support message. Confirm it still appears in Crisp
   **and** posts the one-line heads-up in `#support`.
2. Reply from Crisp. Confirm it reaches the app (~15s). This proves the live path
   is intact and only the retired Slack path was removed.

## Report + checklist

Tell Hayden the Slack toggle state and whether `slack-events` was deleted. In
`docs/LAUNCH_CHECKLIST.md` §10, tick:
- `Turn OFF the Slack app's Event Subscriptions` → `[x]`.

**Not in this task:** the §10 privacy-policy line (add Crisp as a data processor)
— that's content, handled in the legal handoff, not here.
