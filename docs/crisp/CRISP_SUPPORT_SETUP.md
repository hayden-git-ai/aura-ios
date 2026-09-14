# Wire up Crisp for support

This replaces the Slack round-trip with Crisp as the support inbox. Each user
becomes their own conversation in Crisp (by name/email), you reply from the Crisp
inbox or mobile app, and the reply lands back in the user's in-app chat.

The app does not change. Only a Crisp setup + the two edge functions.

Do the parts in order. Parts 1-2 are on Crisp; Parts 3-4 are in Supabase; Part 5
connects the webhook; Part 6 tests; Part 7 retires Slack.

The Supabase project is `xafxoixbxaezijooutlw`.

---

## 1. Create the Crisp workspace (free)

1. Sign up at https://crisp.chat/ (the free plan is enough: shared inbox + mobile
   apps with push).
2. Create your workspace. This creates a "website" (Crisp's word for an inbox).
3. Install the Crisp mobile app and sign in, so replies reach your phone.
4. Get the **Website ID**: open the inbox in a browser. The URL looks like
   `https://app.crisp.chat/website/<WEBSITE_ID>/...`. That UUID is your
   `CRISP_WEBSITE_ID`. (Also under Settings > Website settings.)

## 2. Create a plugin (for the API + webhook)

A private plugin gives the API keypair and the webhook.

1. Go to https://marketplace.crisp.chat/ and sign in (marketplace account is
   separate from the main app; use the same email).
2. Plugins > **New Plugin** > type **Private** > name it "Aura App" > Create.
3. **Tokens**: click "Ask a **development** token" (immediate; a production token
   needs approval and is not required to start). Copy the **identifier** and
   **key**. These are `CRISP_IDENTIFIER` and `CRISP_KEY`, treat them like
   passwords.
4. **Scopes**: grant these two (read + write):
   - `website:conversation:sessions`
   - `website:conversation:messages`
5. **Install the plugin on your website**: in the plugin's Settings, find the
   private install link (Settings > Danger Zone / Visibility) and install it on
   the workspace you made in Part 1. Without this the token cannot post.

(Leave the webhook for Part 5, after the function URL exists.)

---

## 3. Supabase: secrets + migration

**Secrets** (Project Settings > Edge Functions > Secrets). Add:

- `CRISP_IDENTIFIER` = the token identifier from 2.3
- `CRISP_KEY` = the token key from 2.3
- `CRISP_WEBSITE_ID` = the website id from 1.4
- `CRISP_WEBHOOK_SECRET` = the signing secret from Part 5 (add it once you have it)

**Migration** (SQL Editor): run
`server/supabase/migrations/20260911000000_crisp_sessions.sql` once.

## 4. Supabase: deploy the two functions

- **`support-send`** (the app's send path): redeploy with the new contents of
  `server/supabase/functions/support-send/index.ts`. It now relays to Crisp
  instead of Slack. **verify_jwt: ON.**
- **`crisp-events`** (the founders' reply path): deploy a new function named
  exactly `crisp-events` with the contents of
  `server/supabase/functions/crisp-events/index.ts`. **verify_jwt: OFF** (Crisp
  calls it with no Supabase token; it verifies Crisp's signature instead).

Its public URL will be:

```
https://xafxoixbxaezijooutlw.supabase.co/functions/v1/crisp-events
```

---

## 5. Connect the Crisp web hook to that URL

Back in the plugin (marketplace), on its **Settings** tab:

1. Find the **Events** (web hooks) section.
2. Paste the Request URL:
   `https://xafxoixbxaezijooutlw.supabase.co/functions/v1/crisp-events`
3. Subscribe to the **`message:send`** event.
4. Copy the **signing secret** and add it to Supabase secrets as
   `CRISP_WEBHOOK_SECRET` (Part 3), then it is live.

---

## 6. Test the full loop

1. In the app (signed in), Profile > chat bubble > send a message.
2. A new conversation appears in your Crisp inbox, titled with the user's name,
   with the message.
3. Reply from the Crisp inbox (or mobile app).
4. Back in the app, the reply appears within about 15 seconds (the chat polls
   while open), behind the typing indicator.

If a reply does not come through, check the `crisp-events` function logs for
signature or lookup errors, and confirm the plugin is installed on the website.

---

## 7. Retire Slack (once Crisp works)

Support no longer uses Slack. When you are happy with Crisp:

- Turn off the Slack app's Event Subscriptions (so `slack-events` stops receiving
  events), or delete the `slack-events` function.
- You can keep the Slack workspace/channels for the other integrations (bookings,
  revenue, etc.); only the support round-trip moved to Crisp.

---

## Notes

- **AI is off.** Crisp's AI/MagicReply is opt-in; leave it off so replies stay you.
- **Privacy policy:** Crisp is now a data processor for support messages. Add a
  line naming it (same as any third-party support tool). See the launch checklist.
- Replies show on a 15-second poll while the chat is open, plus an immediate pull
  on open. No extra config needed.
