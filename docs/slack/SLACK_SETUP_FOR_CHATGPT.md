# Aura Slack setup (hand this to ChatGPT)

You are setting up Slack for a startup called Aura. The goal is two things:

1. **Support inbox.** When a user messages us inside the Aura app, it shows up in a Slack channel. When Hayden or Jesse reply to that message in Slack, the reply goes back to the user in the app. You are only setting up the Slack side. The reply-delivery wiring is built separately by the engineer (Hayden's dev), so some steps here just collect values and hand them back to Hayden.

2. **Call reminders.** When someone books a call with the founders (through Cal.com), a note and a reminder get posted in Slack so Hayden and Jesse do not miss it.

Your job is the Slack admin work and collecting a short list of values at the end. Hayden will verify everything you do. Do not guess or skip the "values to send back" list at the bottom, it is the most important part.

Work slowly and confirm each screen before moving on. If a button name is slightly different from what is written here, pick the closest match and note it for Hayden.

---

## Part 0: The workspace

Hayden already has a Slack workspace. Use that one. Do not create a new workspace.

If for some reason no workspace is available, create one at https://slack.com/get-started and name it "Aura", then continue.

Make sure Jesse (Hayden's cofounder) is a member of the workspace before you finish. If Jesse is not a member, invite him using the email Hayden gives you (workspace menu > "Invite people to [workspace]").

---

## Part 1: Create the channels

We want a few channels so things stay organized. Create these as **public** channels (public inside the workspace, not open to the internet). Public keeps the setup simple and lets the bot post without extra permission steps.

Create each one with the "+" next to "Channels" in the left sidebar, or "Add channels" > "Create a new channel":

1. `#support` — description: "Messages from users inside the app. Reply in the thread to answer them."
2. `#bookings` — description: "Founder call bookings and reminders from Cal.com."
3. `#alerts` — description: "System and error notices from the Aura backend." (This one is for later, create it now so it exists.)

Make sure both Hayden and Jesse are added to all three channels.

---

## Part 2: Create the Slack app

1. Go to https://api.slack.com/apps
2. Sign in if asked, and make sure the account is the one tied to Hayden's Aura workspace.
3. Click **"Create New App"**.
4. Choose **"From scratch"**.
5. App Name: `Aura Bot`
6. Pick the Aura workspace as the development workspace.
7. Click **"Create App"**.

You are now on the app's settings page. The left sidebar of this page has all the sections you will use below.

---

## Part 3: Bot token scopes (permissions)

1. In the app settings left sidebar, click **"OAuth & Permissions"**.
2. Scroll down to **"Scopes"** > **"Bot Token Scopes"**.
3. Click **"Add an OAuth Scope"** and add each of these, one at a time. Add all of them:
   - `chat:write` — lets the bot post messages.
   - `channels:history` — lets the bot read messages in public channels, so it can catch the founders' replies in `#support`.
   - `channels:read` — lets the bot see channel info.
   - `im:write` — lets the bot open a direct message with Hayden and Jesse for call reminders.
   - `users:read` — lets the bot look up member info.

Do not add any other scopes. If a scope in the list above is not found, note it for Hayden and continue.

---

## Part 4: Install the app and collect the token

1. Still under **"OAuth & Permissions"**, scroll to the top to **"OAuth Tokens for Your Workspace"**.
2. Click **"Install to Workspace"** (or "Install to [workspace name]").
3. Slack shows a permission screen. Review it and click **"Allow"**.
4. After it installs, you will see a **"Bot User OAuth Token"**. It starts with `xoxb-`.
5. **Copy that token.** You will hand it to Hayden at the end. Write it into the "values to send back" list at the bottom. Treat it like a password, do not post it into any public channel or anywhere else.

Now get the signing secret:

6. In the left sidebar, click **"Basic Information"**.
7. Scroll to **"App Credentials"**.
8. Find **"Signing Secret"**, click **"Show"**, and copy it.
9. Add it to the "values to send back" list. This is also a secret, handle it the same way.

---

## Part 5: Invite the bot to the channels

The bot can only see and post in channels it has been added to.

1. Go to the `#support` channel in Slack.
2. In the message box type `/invite @Aura Bot` and send it, or click the channel name at the top > "Integrations" > "Add apps" > add "Aura Bot".
3. Do the same for `#bookings` and `#alerts`.

Confirm the bot appears in the member list of all three channels.

---

## Part 6: Collect the member IDs for reminders

Call reminders will be sent to Hayden and Jesse directly. For that, we need each person's Slack member ID.

For Hayden, then again for Jesse:

1. Click the person's name or avatar to open their profile.
2. Click the three dots ("More") in their profile.
3. Click **"Copy member ID"**. It looks like `U01ABCDEF`.
4. Add both IDs to the "values to send back" list, labeled clearly (Hayden vs Jesse).

Also copy the channel IDs:

5. Right click `#support` in the sidebar > "View channel details" (or open the channel, click its name at the top). At the very bottom of the details panel there is a **Channel ID** like `C01ABCDEF`. Copy it.
6. Do the same for `#bookings` and `#alerts`.
7. Add all three channel IDs to the list, labeled by channel name.

---

## Part 7: Event Subscriptions — DO THIS LAST, AND ONLY AFTER HAYDEN GIVES YOU A URL

This step is what lets the founders' replies in `#support` travel back to the user in the app. It needs a live web address ("Request URL") from Hayden's backend. That address does not exist yet when you first run this guide.

**So: skip this section on your first pass.** Finish everything above, send Hayden the values list, and he will send you back a Request URL. Then come back and do these steps:

1. In the app settings left sidebar, click **"Event Subscriptions"**.
2. Toggle **"Enable Events"** on.
3. In **"Request URL"**, paste the URL Hayden gives you.
4. Wait for Slack to show a green **"Verified"** next to it. If it does not verify, stop and tell Hayden, do not keep retrying.
5. Scroll to **"Subscribe to bot events"**.
6. Click **"Add Bot User Event"** and add: `message.channels`
7. Click **"Save Changes"** at the bottom.
8. Slack may show a yellow banner saying the app must be reinstalled. If so, go to "OAuth & Permissions" > "Reinstall to Workspace" > "Allow". After reinstalling, check with Hayden whether the Bot User OAuth Token changed. If it changed, send him the new one.

---

## Values to send back to Hayden

Fill these in as you go and send the whole block to Hayden at the end. The tokens and secret are sensitive, send them the way Hayden asks (not in a public channel).

```
Bot User OAuth Token (xoxb-...):  __________
Signing Secret:                   __________

Hayden member ID (U...):          __________
Jesse member ID (U...):           __________

#support  channel ID (C...):      __________
#bookings channel ID (C...):      __________
#alerts   channel ID (C...):      __________

Workspace name:                   __________
Confirmed bot is in all 3 channels? (yes/no)
Confirmed Jesse is in the workspace and channels? (yes/no)
```

---

## Part 8: The full channel list (create these too)

We want Slack organized by area so nothing gets lost. Create the channels below as **public** channels, same as before, and add both Hayden and Jesse to each one.

Important rule: **only create a channel if the thing that feeds it is actually running.** An empty channel is just noise. The list is split into "create now" and "create later". If you are unsure whether a service is live, ask Hayden before creating that channel, or leave it in the "later" pile.

You already created `#support`, `#bookings`, `#alerts`, `#general`, and `#marketing`. Keep those.

### Create now

- `#rev-app` — description: "App Store revenue: trials, subscriptions, cancellations, and paywall conversions."
- `#bank` — description: "Mercury bank transaction notices."
- `#analytics` — description: "PostHog product insights and alerts."
- `#feedback` — description: "Featurebase feature requests and user feedback."

Only create `#analytics`, `#feedback`, or `#bank` if Hayden confirms PostHog, Featurebase, or Mercury are set up. If he is not sure, skip that one for now.

### Create later (leave these for when the integration is built, do not create yet unless Hayden says so)

- `#rev-web` — "Web funnel revenue from Paddle and Web2Wave."
- `#ops-api` — "Gemini and OpenAI: quota warnings and fallback notices."
- `#releases` — "App Store Connect build and review status."
- `#reviews` — "New App Store reviews."
- `#growth-ads` — "Meta Ads spend and performance alerts."
- `#growth-web` — "Website form submissions and signups."

### Organize the sidebar (optional, per person)

Slack channels are a flat list, but each person can group their own sidebar into collapsible sections. If you can, set up sections named **Revenue**, **Growth**, **Product**, **Customer**, and **Ops**, and drag the channels into them like this:

- Revenue: `#rev-app`, `#rev-web`
- Growth: `#marketing`, `#growth-ads`, `#growth-web`
- Product: `#alerts`, `#ops-api`, `#analytics`, `#releases`, `#feedback`
- Customer: `#support`, `#bookings`, `#reviews`
- Ops: `#general`, `#bank`

Sections are personal to each user, so this only organizes the sidebar for whoever is logged in. That is fine, Hayden and Jesse can each set up their own later.

---

## Part 9: Connect the native service integrations

Several tools post to Slack on their own. These do NOT use the Aura Bot. Each one is connected from inside that service, and each will ask you to sign in to that service and then pick a Slack channel to post to. If you are not logged in to a service, note it for Hayden and move on, he will finish that one himself.

For each, connect it and point it at the channel shown:

- **RevenueCat** > point at `#rev-app`. In RevenueCat: Project settings > Integrations > Slack (or Apps > Slack), authorize, choose `#rev-app`, and enable the events for new subscriptions, trials, cancellations, and refunds.
- **Superwall** > point at `#rev-app` as well (same channel, it is all App Store revenue). In Superwall: Settings > Integrations, connect Slack, choose `#rev-app`.
- **PostHog** > point at `#analytics`. In PostHog: Data pipelines / Apps, add the Slack destination, choose `#analytics`.
- **Featurebase** > point at `#feedback`. In Featurebase: Settings > Integrations > Slack, choose `#feedback`.
- **Mercury** > point at `#bank`. In Mercury: Settings > Notifications or Integrations > Slack, choose `#bank`.

Only do the ones whose service Hayden confirms is set up. For any you connect, note in your report which channel you pointed it at, so Hayden can verify.

---

## What NOT to do

- Do not enable "Socket Mode". We are using a web address, not sockets.
- Do not add scopes beyond the five listed.
- Do not make the channels into shared or externally-connected channels.
- Do not paste the Bot Token or Signing Secret into any Slack channel, email subject line, or public place.
- Do not complete Part 7 until Hayden sends you a Request URL.
