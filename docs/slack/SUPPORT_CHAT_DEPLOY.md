# Deploy the two-way support chat

The code is built. This is the wiring to make it live: set two Slack secrets, apply
two migrations, deploy two edge functions, then point Slack at the receiver. Do the
steps in order. Steps 1 to 4 are yours (Supabase dashboard); step 5 is the piece you
hand back to ChatGPT.

The Supabase project is `xafxoixbxaezijooutlw`.

---

## 1. Set the two Slack secrets

Supabase dashboard > Project Settings > Edge Functions > Secrets. Add:

- `SLACK_BOT_TOKEN` = the `xoxb-...` token ChatGPT found.
- `SLACK_SIGNING_SECRET` = the signing secret ChatGPT found.

(These sit alongside the ones already there: `OPENAI_API_KEY`, etc. `SUPABASE_URL`,
`SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically.)

## 2. Apply the two migrations

Supabase dashboard > SQL Editor. Run each file's contents once:

- `server/supabase/migrations/20260909000000_support_messages.sql` (the message table)
- `server/supabase/migrations/20260910000000_support_threads.sql` (user to Slack-thread map)

Both use `create table if not exists`, so re-running is harmless.

## 3. Deploy `support-send` (the app's send path)

Dashboard > Edge Functions > Deploy a new function (or the editor). Name it exactly
`support-send`. Paste the contents of `server/supabase/functions/support-send/index.ts`.

- **verify_jwt: ON.** The app sends the user's session token; the gateway rejects
  anything unsigned, and the function reads the user id from that token.

## 4. Deploy `slack-events` (the founders' reply path)

Deploy a function named exactly `slack-events`. Paste the contents of
`server/supabase/functions/slack-events/index.ts`.

- **verify_jwt: OFF.** Slack calls this with no Supabase token; the function
  authenticates every request by checking the Slack signature instead.

Its public URL will be:

```
https://xafxoixbxaezijooutlw.supabase.co/functions/v1/slack-events
```

That is the Request URL for step 5.

---

## 5. Hand back to ChatGPT: finish Event Subscriptions (Part 7 of the setup guide)

Give ChatGPT this Request URL:

```
https://xafxoixbxaezijooutlw.supabase.co/functions/v1/slack-events
```

Then have it complete Part 7 of `SLACK_SETUP_FOR_CHATGPT.md`:

1. App settings > Event Subscriptions > enable events.
2. Paste the Request URL. Wait for the green "Verified". (The function answers
   Slack's one-time challenge, so it should verify immediately once deployed.)
3. Under "Subscribe to bot events", add `message.channels`.
4. Save. If Slack asks to reinstall the app, reinstall and confirm the bot token
   did not change (if it did, update `SLACK_BOT_TOKEN` in step 1).

---

## How to test the full loop

1. In the app (signed in), open Profile > the chat bubble > send a message.
2. It should appear as a new thread in `#support`, pinging Hayden and Jesse, with
   the user's name and email in the thread header.
3. Reply **inside that thread** in Slack.
4. Back in the app, the reply appears within about 15 seconds (the chat polls while
   open). Reopening the chat also pulls it immediately.

If a reply does not come through: check the `slack-events` function logs in the
dashboard for signature or lookup errors, and confirm the bot is a member of
`#support`.

---

## Notes

- Replies show up on a 15-second poll while the chat screen is open, plus an
  immediate pull when it opens. That needs no extra Supabase config. True realtime
  (instant, even push) is a later upgrade and would need Realtime enabled on the
  `support_messages` table.
- Only replies posted **in the thread** map back to a user. A stray top-level
  message in `#support` is ignored on purpose.
- The bot never echoes its own posts (they carry a bot id), so there is no loop.
