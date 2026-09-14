# Crisp setup for Aura (hand this to ChatGPT)

You are finishing a Crisp setup for a startup called Aura. Crisp is a customer
support inbox. We are connecting it so that when someone messages support inside
the Aura app, it shows up as a conversation in Crisp, and when the founder
replies in Crisp, the reply goes back to the user in the app.

Most of the backend is already built. **Your job is only the Crisp-side clicking,
plus collecting four values at the end and giving them to Hayden.** Do not paste
those four values into any public place; hand them to Hayden directly so he can
put them into his server settings.

Work carefully and confirm each screen. Crisp has TWO separate websites and it is
confusing, so read this note first:

- **`app.crisp.chat`** = the inbox (where support conversations live).
- **`marketplace.crisp.chat`** = the developer area (where "plugins", API tokens,
  and webhooks live).

A private plugin named **"Aura App"** has already been created in the marketplace.
You are finishing it. If for some reason it does not exist, tell Hayden and stop.

---

## Step 1: Link the plugin to the workspace (required)

The API token will not work until the plugin is linked to Hayden's workspace.

1. Go to **https://marketplace.crisp.chat/** and sign in (Hayden's account,
   email `hayden@downloadaura.app`).
2. Left sidebar > **Plugins** > open **"Aura App"**.
3. Click **"Install Plugin on Workspace"** (top right).
4. Select the **Aura** workspace (it shows as `downloadaura.app`) and confirm /
   allow. Approve all scopes it asks for.
5. Success looks like: the orange warning that said "The development token will
   not be usable until you link a trusted workspace" is gone.

## Step 2: Collect the development token values

1. In **"Aura App"**, open the **Tokens** tab.
2. In the **Development Token** section, use the copy buttons to copy these three,
   and label each one for Hayden:
   - **Identifier**  → label it `CRISP_IDENTIFIER`
   - **Key**         → label it `CRISP_KEY`
   - **Signing Secret** → label it `CRISP_WEBHOOK_SECRET`
3. These are secrets. Keep them to give to Hayden privately.

## Step 3: Get the Website ID

1. Go to **https://app.crisp.chat/** (the inbox).
2. Look at the browser URL. It looks like
   `https://app.crisp.chat/website/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX/...`.
3. That UUID is the **Website ID** → label it `CRISP_WEBSITE_ID`.
   (If unsure, it is also under Settings > Workspace Settings.)

## Step 4: Set up the web hook (this is what sends replies back to the app)

1. Back in **https://marketplace.crisp.chat/** > **"Aura App"** > the **Settings**
   tab.
2. Find the **Events** (web hooks) section.
3. Set / paste the web hook URL to exactly:
   ```
   https://xafxoixbxaezijooutlw.supabase.co/functions/v1/crisp-events
   ```
4. Subscribe to the event named **`message:send`** (only that one).
5. Save.

## Step 5 (optional, for later, NOT blocking): request a production token

The development token works now but is limited to 500 API requests per day. A
production token lifts that. It needs a quick review, so request it now so it is
ready later. This does not block anything.

1. In the **Tokens** tab, scroll to **Production Token**.
2. Under **Scopes**, type "conversation" in the scope picker and add these two,
   choosing the **write** version of each:
   - `website:conversation:sessions`
   - `website:conversation:messages`
3. Do not add any other scopes.
4. Submit the production-token request. For the justification, use:
   *"Private integration syncing our iOS app's in-app support chat with our Crisp
   inbox (create conversations, send and receive messages)."*

---

## Report back to Hayden

Give Hayden this block (the three secrets privately, not in any public channel):

```
CRISP_IDENTIFIER      = __________
CRISP_KEY             = __________
CRISP_WEBHOOK_SECRET  = __________  (the Signing Secret)
CRISP_WEBSITE_ID      = __________

Workspace linked? (yes/no)
Web hook saved with message:send subscribed? (yes/no)
Production token requested? (yes/no — optional)
```

## What NOT to do

- Do not treat the production token as required; the development token works now.
- Do not add scopes beyond the two listed.
- Do not turn on any AI / Bot / MagicReply feature (the founder answers himself).
- Do not paste the Identifier, Key, or Signing Secret into any public place.
