import assert from "node:assert/strict";
import test from "node:test";

import {
  createFreshSignedSupportURL,
  fetchTrustedSupportMedia,
  rasterWithinPixelBudget,
  SUPPORT_MEDIA_MAX_BYTES,
  trustedSupportMedia,
} from "./support-media.ts";
import type { FetchLike } from "./checked-fetch.ts";

const base = "https://project.supabase.co";
const uid = "11111111-1111-4111-8111-111111111111";
const token = "header.payload.signature";
const own = `${base}/storage/v1/object/sign/user-media/${uid}/support/22222222-2222-4222-8222-222222222222.jpg?token=${token}`;

test("caller MIME cannot bypass own-image validation", () => {
  // No MIME is an input: every supplied attachment URL resolves through the
  // trusted image download/decode path, including application/octet-stream.
  const resolved = trustedSupportMedia(base, own, uid);
  assert.equal(resolved?.objectPath, `${uid}/support/22222222-2222-4222-8222-222222222222.jpg`);
});

test("rejects another owner's object", () => {
  const other = own.replace(uid, "33333333-3333-4333-8333-333333333333");
  assert.equal(trustedSupportMedia(base, other, uid), null);
});

test("rejects attacker origins and non-HTTPS aliases", () => {
  assert.equal(trustedSupportMedia(base, own.replace(base, "https://attacker.example"), uid), null);
  assert.equal(trustedSupportMedia(base, own.replace("https://", "http://"), uid), null);
});

test("rejects encoded separators, traversal, and double encoding", () => {
  for (const path of [
    `${uid}%2Fsupport%2Ffile.jpg`,
    `${uid}/support/%2e%2e`,
    `${uid}/support/%252e%252e`,
    `${uid}/support/file%5c.jpg`,
  ]) {
    const url = `${base}/storage/v1/object/sign/user-media/${path}?token=${token}`;
    assert.equal(trustedSupportMedia(base, url, uid), null);
  }
  const literal = `${base}/storage/v1/object/sign/user-media/${uid}/support/folder/../file.jpg?token=${token}`;
  assert.equal(trustedSupportMedia(base, literal, uid), null);
});

test("rejects missing or malformed caller signing tokens", () => {
  assert.equal(trustedSupportMedia(base, own.split("?")[0], uid), null);
  assert.equal(trustedSupportMedia(base, own.replace(token, "bogus"), uid), null);
});

test("valid own image downloads through trusted API with redirects disabled", async () => {
  const media = trustedSupportMedia(base, own, uid)!;
  let requested = "";
  let redirect: RequestRedirect | undefined;
  const stub: FetchLike = async (input, init) => {
    requested = String(input);
    redirect = init?.redirect;
    return new Response(new Uint8Array([0xff, 0xd8, 0xff]), { status: 200 });
  };
  const bytes = await fetchTrustedSupportMedia(media, "service-key", stub);
  assert.equal(requested, `${base}/storage/v1/object/authenticated/user-media/${uid}/support/22222222-2222-4222-8222-222222222222.jpg`);
  assert.equal(redirect, "error");
  assert.deepEqual([...bytes], [0xff, 0xd8, 0xff]);
});

test("redirect response is rejected", async () => {
  const media = trustedSupportMedia(base, own, uid)!;
  const stub: FetchLike = async () => new Response(null, {
    status: 302,
    headers: { location: "https://attacker.example/payload" },
  });
  await assert.rejects(fetchTrustedSupportMedia(media, "service-key", stub));
});

test("download byte budget rejects declared and actual oversized bodies", async () => {
  const media = trustedSupportMedia(base, own, uid)!;
  const declared: FetchLike = async () => new Response(new Uint8Array(), {
    status: 200,
    headers: { "content-length": String(SUPPORT_MEDIA_MAX_BYTES + 1) },
  });
  await assert.rejects(fetchTrustedSupportMedia(media, "service-key", declared));

  let cancelled = false;
  const actual: FetchLike = async () => new Response(new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(new Uint8Array(6 * 1024 * 1024));
      controller.enqueue(new Uint8Array(6 * 1024 * 1024));
    },
    cancel() { cancelled = true; },
  }));
  await assert.rejects(fetchTrustedSupportMedia(media, "service-key", actual));
  assert.equal(cancelled, true);
});

test("pixel budget rejects a huge PNG header before decode", () => {
  const normal = new Uint8Array(24);
  normal.set([0x89, 0x50, 0x4e, 0x47]);
  new DataView(normal.buffer).setUint32(16, 2048);
  new DataView(normal.buffer).setUint32(20, 2048);
  assert.equal(rasterWithinPixelBudget(normal), true);

  const huge = normal.slice();
  new DataView(huge.buffer).setUint32(16, 50_000);
  new DataView(huge.buffer).setUint32(20, 50_000);
  assert.equal(rasterWithinPixelBudget(huge), false);
});

test("JPEG dimensions require strict marker grammar and one SOF", () => {
  const sof = [
    0xff, 0xc0, 0x00, 0x11, 0x08, 0x08, 0x00, 0x08, 0x00, 0x03,
    0x01, 0x11, 0x00, 0x02, 0x11, 0x00, 0x03, 0x11, 0x00,
  ];
  const sos = [0xff, 0xda, 0x00, 0x08, 0x03, 0x01, 0x00, 0x02, 0x00, 0x03];
  assert.equal(rasterWithinPixelBudget(new Uint8Array([0xff, 0xd8, ...sof, ...sos])), true);
  assert.equal(rasterWithinPixelBudget(new Uint8Array([0xff, 0xd8, 0x42, ...sof, ...sos])), false);
  assert.equal(rasterWithinPixelBudget(new Uint8Array([0xff, 0xd8, ...sof, ...sof, ...sos])), false);
});

test("fresh signed URL is validated and replaces caller signature", async () => {
  const media = trustedSupportMedia(base, own, uid)!;
  const fresh = `${base}/storage/v1/object/sign/user-media/${uid}/support/22222222-2222-4222-8222-222222222222.jpg?token=fresh.payload.signature`;
  const stub: FetchLike = async () => Response.json({ signedURL: fresh });
  assert.equal(await createFreshSignedSupportURL(media, "service-key", stub), fresh);
  assert.notEqual(fresh, own);
});
