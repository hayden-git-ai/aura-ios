/**
 * App Store review poller.
 *
 * Apple does not send customer reviews through App Store Connect webhooks, so
 * this function checks Apple's public RSS review feeds and posts new reviews to
 * Slack #reviews. It stores seen review IDs in app_store_review_alerts to avoid
 * duplicate alerts.
 *
 * Deploy with verify_jwt OFF. Calls are protected by APP_STORE_REVIEWS_POLL_SECRET.
 */

const APP_ID = "6809618566";
const APP_STORE_URL = `https://apps.apple.com/app/id${APP_ID}`;

interface Review {
  id: string;
  country: string;
  title: string;
  content: string;
  rating: number;
  author: string;
  updated: string;
  url: string;
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") return json({ error: "POST only" }, 405);

  const secret = Deno.env.get("APP_STORE_REVIEWS_POLL_SECRET");
  if (!secret || request.headers.get("x-poll-secret") !== secret) {
    return json({ error: "unauthorized" }, 401);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const token = Deno.env.get("SLACK_BOT_TOKEN");
  const channel = Deno.env.get("SLACK_REVIEWS_CHANNEL_ID");
  if (!url || !key || !token || !channel) return json({ error: "server misconfigured" }, 500);

  const countries = (Deno.env.get("APP_STORE_REVIEW_COUNTRIES") || "us")
    .split(",")
    .map((c) => c.trim().toLowerCase())
    .filter(Boolean);

  let posted = 0;
  for (const country of countries) {
    const reviews = await fetchReviews(country).catch(() => []);
    // Oldest first, so Slack reads naturally if several arrive between polls.
    for (const review of reviews.reverse()) {
      const isNew = await rememberReview(url, key, review);
      if (!isNew) continue;
      await postReviewToSlack(token, channel, review);
      posted++;
    }
  }

  return json({ ok: true, posted }, 200);
});

async function fetchReviews(country: string): Promise<Review[]> {
  const feedUrl =
    `https://itunes.apple.com/${country}/rss/customerreviews/id=${APP_ID}/sortBy=mostRecent/json`;
  const res = await fetch(feedUrl, {
    headers: { accept: "application/json" },
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) return [];

  const body = await res.json();
  const entries = body?.feed?.entry;
  const list = Array.isArray(entries) ? entries : entries ? [entries] : [];

  return list
    .map((entry: any): Review | null => {
      const id = label(entry?.id);
      const title = label(entry?.title);
      const content = label(entry?.content);
      const rating = Number(label(entry?.["im:rating"]));
      if (!id || !title || !Number.isFinite(rating)) return null;

      return {
        id,
        country,
        title,
        content,
        rating,
        author: label(entry?.author?.name) || "App Store reviewer",
        updated: label(entry?.updated),
        url: entry?.link?.attributes?.href || APP_STORE_URL,
      };
    })
    .filter((r: Review | null): r is Review => !!r);
}

function label(value: any): string {
  return typeof value?.label === "string" ? value.label.trim() : "";
}

async function rememberReview(url: string, key: string, review: Review): Promise<boolean> {
  const res = await fetch(`${url}/rest/v1/app_store_review_alerts`, {
    method: "POST",
    headers: {
      apikey: key,
      authorization: `Bearer ${key}`,
      "content-type": "application/json",
      prefer: "resolution=ignore-duplicates,return=minimal",
    },
    signal: AbortSignal.timeout(5_000),
    body: JSON.stringify({
      review_id: review.id,
      country: review.country,
      title: review.title,
      rating: review.rating,
      author_name: review.author,
      updated_at: review.updated || null,
    }),
  });
  return res.status === 201;
}

async function postReviewToSlack(token: string, channel: string, review: Review): Promise<void> {
  const stars = ":star:".repeat(Math.max(0, Math.min(5, review.rating)));
  const quote = truncate(review.content || review.title, 700);
  const text = [
    `*New App Store review* (${review.country.toUpperCase()})`,
    `${stars} ${review.rating}/5 — *${escapeSlack(review.title)}*`,
    quote ? `>${escapeSlack(quote).replace(/\n/g, "\n>")}` : "",
    `Reviewer: ${escapeSlack(review.author)}`,
    `<${review.url || APP_STORE_URL}|Open review>`,
  ].filter(Boolean).join("\n");

  await fetch("https://slack.com/api/chat.postMessage", {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json; charset=utf-8",
    },
    signal: AbortSignal.timeout(5_000),
    body: JSON.stringify({ channel, text, unfurl_links: false }),
  });
}

function truncate(value: string, max: number): string {
  return value.length <= max ? value : `${value.slice(0, max - 3)}...`;
}

function escapeSlack(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
