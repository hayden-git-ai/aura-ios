/**
 * Photo-proof verification.
 *
 * Exists for one reason: the Gemini key cannot ship inside the app. Anything in
 * an iOS binary can be pulled out of it, and a leaked key is somebody else's
 * traffic on your bill. The app talks to this; this talks to Google.
 *
 * Deliberately thin. It holds no state, stores no images, and makes exactly one
 * decision. Pass or fail. Which it hands straight back.
 */

/**
 * Pinned here, not in the app. Flash versions move, and swapping models to
 * compare cost or accuracy should never need an App Store release.
 *
 * Chosen by testing three candidates against the same photos: lite was the
 * fastest by a wide margin (about 1.2s against 3 to 6s) and reached the same
 * verdicts, including catching a photo of a photo. The judgement here is easy,
 * so the cheapest model that gets it right is the right one.
 */
const MODEL = "gemini-3.5-flash-lite";

/** Google gives up long before this; the app gives up at 15. */
const UPSTREAM_TIMEOUT_MS = 12_000;

/**
 * Fallback model, a different provider on purpose. If Gemini errors (a Google
 * outage, a block, a timeout), we ask OpenAI the same question before giving up,
 * so a provider outage doesn't hand every user a free pass. Chosen for reliable
 * vision at low cost; only ever runs when Gemini has already failed, so its
 * latency and price barely matter. No-op until OPENAI_API_KEY is set.
 */
const FALLBACK_MODEL = "gpt-5-mini";

interface Verdict {
  passed: boolean;
  /** What the model saw in THIS photo. Shown on both screens. */
  reason: string;
  /**
   * What to point the camera at next time. Only meaningful on a fail, where
   * the screen leads with it: being told how to fix it is more use than being
   * told what went wrong, and it goes above the reason for that reason.
   *
   * Empty on a pass. There is nothing to fix.
   */
  fix: string;
  /**
   * Google refused to look at the photo.
   *
   * Safety refusal is distinct from unavailable verification. Both reject the
   * photo, but this flag lets the app show neutral blocked-content guidance.
   */
  blocked?: boolean;
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") {
    return json({ error: "POST only" }, 405);
  }

  // Emergency stop. Flip PROOF_DISABLED and every request short-circuits here,
  // before the key check, the rate gate, and any Gemini call, so all spend stops
  // the moment the secret is set. No App Store release, no redeploy: it is read
  // fresh on each request.
  //
  // Unavailable verification never awards a pass or coins.
  if (isDisabled()) {
    return json({ error: "photo verification temporarily unavailable" }, 503);
  }

  // Two ways in, checked strongest first.
  //
  // 1. A signed-in user: a real Supabase access token in the Authorization
  //    header. This is genuine authentication — the token is verified against
  //    Auth and can't be forged or extracted from the binary. When present, the
  //    quota is counted per USER, which no device-id fake can multiply.
  //
  // 2. Not-yet-signed-in: the shared app key. Weak by nature (it ships in the
  //    binary), but it keeps the bare URL worthless, and these requests are
  //    capped per DEVICE. This path exists only for users who haven't signed in
  //    yet; drop it once sign-in is mandatory and this becomes JWT-only.
  const bearer = request.headers.get("authorization");
  const userId = bearer?.startsWith("Bearer ")
    ? await verifyUser(bearer.slice(7))
    : null;

  if (!userId) {
    const expected = Deno.env.get("AURA_APP_KEY");
    if (!expected || request.headers.get("x-aura-key") !== expected) {
      return json({ error: "unauthorized" }, 401);
    }
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return json({ error: "GEMINI_API_KEY not set" }, 500);
  }

  // The control that actually caps the bill. A signed-in user is counted by
  // user id (unfakeable); everyone else by device id. A real person never
  // reaches the ceiling; a scraper hits a wall on every identity it can fake.
  //
  // Missing device header collapses to one shared bucket rather than being waved
  // through, so omitting it is worse than sending it.
  const rateKey = userId
    ? `user:${userId}`
    : `device:${request.headers.get("x-aura-device") ?? "unknown"}`;
  const gate = await withinLimit(rateKey);
  if (!gate.ok) {
    return json({ error: "daily limit reached", used: gate.used }, 429);
  }

  let body: { image?: string; hint?: string; habitName?: string };
  try {
    body = await request.json();
  } catch {
    return json({ error: "malformed body" }, 400);
  }

  const { image, hint, habitName } = body;
  if (!image || !habitName) {
    return json({ error: "image and habitName are required" }, 400);
  }
  // A 768px JPEG lands around 60–120KB, so ~160KB of base64. Anything far past
  // that isn't coming from our app.
  if (image.length > 400_000) {
    return json({ error: "image too large" }, 413);
  }
  // The client sends JPEG only. Reject arbitrary base64 before a permissive
  // model can judge it, so blank or malformed payloads never earn a pass.
  let imageBytes: Uint8Array;
  try {
    imageBytes = Uint8Array.from(atob(image), (char) => char.charCodeAt(0));
  } catch {
    return json({ error: "image is not valid base64" }, 400);
  }
  if (imageBytes.length < 4 || imageBytes[0] !== 0xff || imageBytes[1] !== 0xd8
      || imageBytes[imageBytes.length - 2] !== 0xff
      || imageBytes[imageBytes.length - 1] !== 0xd9) {
    return json({ error: "image must be a JPEG" }, 415);
  }

  try {
    return json(await judge(image, habitName, hint ?? "", apiKey), 200);
  } catch (geminiError) {
    // Gemini failed. Before giving up, try the fallback provider, so a Google
    // outage doesn't turn into a free pass for everyone. Only if BOTH providers
    // fail do we return non-200, which the app treats as its own fallback and
    // decides for itself what to do with the user standing there.
    const fallbackKey = Deno.env.get("OPENAI_API_KEY");
    if (fallbackKey) {
      // Observability only (no secrets, image, or user data): confirms the
      // Gemini->OpenAI fallback actually engaged in production.
      console.log("verify-proof: gemini failed, trying openai fallback");
      try {
        const verdict = await judgeFallback(image, habitName, hint ?? "", fallbackKey);
        console.log("verify-proof: openai fallback returned verdict");
        return json(verdict, 200);
      } catch (_fallbackError) {
        // Both providers down. Fall through to the 502 below.
      }
    }
    return json({ error: String(geminiError) }, 502);
  }
});

/**
 * Validates a Supabase access token against Auth and returns the user id, or
 * null if it is missing, expired, or forged. A network failure also returns
 * null, which drops the request to the shared-key path rather than failing a
 * real user standing there having done the habit.
 */
async function verifyUser(jwt: string): Promise<string | null> {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) return null;
  try {
    const r = await fetch(`${url}/auth/v1/user`, {
      headers: { authorization: `Bearer ${jwt}`, apikey: anon },
      signal: AbortSignal.timeout(3_000),
    });
    if (!r.ok) return null;
    const user = await r.json();
    return typeof user?.id === "string" ? user.id : null;
  } catch {
    return null;
  }
}

/**
 * Counts this request against the caller's day and says whether it may proceed.
 *
 * The increment happens inside Postgres so two requests landing together can't
 * both read the same number: the row is updated and returns its own new value
 * in one statement.
 *
 * Fails open. If the database is unreachable, verification still works and the
 * ceiling is what's lost. Losing the cap for a few minutes is a smaller problem
 * than every user in the world being unable to earn.
 */
async function withinLimit(subject: string): Promise<{ ok: boolean; used: number }> {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const limit = Number(Deno.env.get("PROOF_DAILY_LIMIT") ?? "60");
  if (!url || !key) return { ok: true, used: 0 };

  try {
    const r = await fetch(`${url}/rest/v1/rpc/bump_proof_usage`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        apikey: key,
        authorization: `Bearer ${key}`,
      },
      signal: AbortSignal.timeout(3_000),
      body: JSON.stringify({ p_device: subject, p_limit: limit }),
    });
    if (!r.ok) return { ok: true, used: 0 };
    const rows = await r.json();
    const row = Array.isArray(rows) ? rows[0] : rows;
    return { ok: Boolean(row?.allowed), used: Number(row?.used ?? 0) };
  } catch {
    return { ok: true, used: 0 };
  }
}

async function judge(
  imageBase64: string,
  habitName: string,
  hint: string,
  apiKey: string,
): Promise<Verdict> {
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-goog-api-key": apiKey,
      },
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: prompt(habitName, hint) },
              { inline_data: { mime_type: "image/jpeg", data: imageBase64 } },
            ],
          },
        ],
        generationConfig: {
          // Structured output rather than parsing prose. The schema is enforced
          // upstream, so the app never sees a verdict it can't read.
          responseMimeType: "application/json",
          responseSchema: {
            type: "OBJECT",
            properties: {
              passed: { type: "BOOLEAN" },
              reason: { type: "STRING" },
              fix: { type: "STRING" },
            },
            required: ["passed", "reason", "fix"],
          },
          // Zero, because the same photo should get the same answer twice. A
          // verifier that's occasionally generous is one people learn to retry
          // against.
          temperature: 0,
        },
      }),
    },
  );

  if (!response.ok) {
    throw new Error(`gemini ${response.status}: ${await response.text()}`);
  }

  const data = await response.json();

  // Checked BEFORE looking for the verdict text, because a block has no verdict
  // text and would otherwise land in the throw below, become a 502, and be paid
  // out as a fallback.
  //
  // Two shapes to catch: Gemini rejects the request outright (`promptFeedback`,
  // no candidates at all), or it starts a candidate and stops it
  // (`finishReason`). The names have moved between API versions, so this checks
  // the set rather than one string.
  const blockedReasons = ["SAFETY", "PROHIBITED_CONTENT", "IMAGE_SAFETY", "BLOCKLIST"];
  if (
    data?.promptFeedback?.blockReason ||
    blockedReasons.includes(data?.candidates?.[0]?.finishReason ?? "")
  ) {
    return { passed: false, reason: "", fix: "", blocked: true };
  }

  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof text !== "string") {
    throw new Error("no verdict in response");
  }

  const parsed = JSON.parse(text) as Verdict;
  if (typeof parsed.passed !== "boolean") {
    throw new Error("invalid passed field");
  }
  const passed = parsed.passed;
  return {
    passed,
    reason: String(parsed.reason ?? "").slice(0, 140),
    // Dropped on a pass even when the model writes one. The schema requires the
    // field, so it fills it in regardless, and "next time try…" under a
    // celebration reads as a note of criticism nobody asked for.
    fix: passed ? "" : String(parsed.fix ?? "").slice(0, 140),
  };
}

/**
 * The same judgement, asked of OpenAI, for when Gemini is unavailable. Uses the
 * identical prompt and the identical structured-output schema, so the verdict
 * shape and the fox's voice are the same whichever provider answered. A refusal
 * is treated as a block, matching the Gemini path.
 */
async function judgeFallback(
  imageBase64: string,
  habitName: string,
  hint: string,
  apiKey: string,
): Promise<Verdict> {
  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${apiKey}`,
    },
    signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
    body: JSON.stringify({
      model: FALLBACK_MODEL,
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: prompt(habitName, hint) },
            {
              type: "image_url",
              image_url: { url: `data:image/jpeg;base64,${imageBase64}` },
            },
          ],
        },
      ],
      // Structured output, same schema as Gemini, so the app reads one shape.
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "verdict",
          strict: true,
          schema: {
            type: "object",
            properties: {
              passed: { type: "boolean" },
              reason: { type: "string" },
              fix: { type: "string" },
            },
            required: ["passed", "reason", "fix"],
            additionalProperties: false,
          },
        },
      },
    }),
  });

  if (!response.ok) {
    throw new Error(`openai ${response.status}: ${await response.text()}`);
  }

  const data = await response.json();
  const choice = data?.choices?.[0];

  // A safety refusal has no verdict and must not fall through to the throw
  // below (which would become a 502 and be paid out), same as the Gemini block.
  if (choice?.message?.refusal || choice?.finish_reason === "content_filter") {
    return { passed: false, reason: "", fix: "", blocked: true };
  }

  const text = choice?.message?.content;
  if (typeof text !== "string") {
    throw new Error("no verdict in openai response");
  }

  const parsed = JSON.parse(text) as Verdict;
  if (typeof parsed.passed !== "boolean") {
    throw new Error("invalid passed field");
  }
  const passed = parsed.passed;
  return {
    passed,
    reason: String(parsed.reason ?? "").slice(0, 140),
    fix: passed ? "" : String(parsed.fix ?? "").slice(0, 140),
  };
}

/**
 * The judgement, and the voice it answers in.
 *
 * Two things it has to get right. It must be strict enough that a photo of a
 * screen doesn't pass. People will try, and a verifier that can be beaten by
 * pointing a phone at a phone is decoration. And it must be generous about
 * everything else: this is somebody who just did the thing, and a fussy
 * verifier costs them the reward they earned.
 *
 * `reason` and `fix` are asked for separately because the failure screen shows
 * them as two lines and they do different jobs. Rolled into one sentence, the
 * diagnosis swallows the instruction, and the instruction is the part that
 * gets somebody to a passing photo.
 */
function prompt(habitName: string, hint: string): string {
  return [
    `You are checking a photo somebody took as proof they did this habit: "${habitName}".`,
    hint ? `A good photo shows: ${hint}` : "",
    "",
    "Pass if the photo plausibly shows the habit being done or about to be done.",
    "Be generous about framing, lighting, angle and mess. People take these in a hurry.",
    "",
    "Fail only if:",
    "- the photo has nothing to do with the habit",
    "- it is a photo of a screen, a screenshot, or an image of an image",
    "- it is black, blank, too dark or blurred to tell what it shows",
    "- it shows only a small or unrelated part of the scene, with no credible evidence of the habit",
    "",
    "Both fields are spoken by Aura, a dry, warm fox talking to the user like a friend.",
    "Write in Aura's voice: all lowercase, casual and spoken, a little dry, never corporate.",
    "Full natural sentences, not clipped fragments. No emoji, no exclamation marks, straight quotes only.",
    "",
    "Write two fields, each one sentence, under 15 words, no preamble and no apology.",
    "",
    "reason: what you actually see in this photo, spoken to them.",
    "  on a pass, be warm about it, like you're genuinely pleased for them.",
    "  on a fail, say what the photo shows instead, plainly and a little dryly.",
    "  fail examples: \"that's just your desk, i can't find the book anywhere.\"",
    "                 \"that's a photo of a screen, nice try.\"",
    "                 \"it's way too dark, i can't make anything out.\"",
    "",
    "fix: on a fail, one casual instruction for THIS habit that would get them a passing shot.",
    "  say it for this habit specifically, not in general.",
    "  fail examples: \"open the book up and get it in the frame, then try again.\"",
    "                 \"point it at the real thing, not a screen.\"",
    "                 \"turn a light on and take another one.\"",
    "  on a pass, leave it as an empty string.",
  ]
    .filter(Boolean)
    .join("\n");
}

/**
 * The kill switch. On when PROOF_DISABLED is set to any obvious truthy value.
 * Anything else, including unset, is off, so the switch is off by default and
 * has to be turned on deliberately.
 */
function isDisabled(): boolean {
  const v = (Deno.env.get("PROOF_DISABLED") ?? "").trim().toLowerCase();
  return v === "1" || v === "true" || v === "on" || v === "yes";
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
