import type { FetchLike } from "./checked-fetch.ts";

const SIGNED_ROUTE = "/storage/v1/object/sign/user-media/";

export interface TrustedSupportMedia {
  objectPath: string;
  downloadURL: string;
  uploadURL: string;
  signURL: string;
}

export const SUPPORT_MEDIA_MAX_BYTES = 10 * 1024 * 1024;
export const SUPPORT_MEDIA_MAX_PIXELS = 40_000_000;

/// Accepts only the authenticated user's canonical `<uid>/support/<file>` path
/// on this exact HTTPS Supabase origin. Encoded separators, traversal, fragments,
/// alternate origins and ambiguous encodings are rejected.
export function trustedSupportMedia(
  supabaseURL: string,
  suppliedURL: string,
  uid: string,
): TrustedSupportMedia | null {
  try {
    const base = new URL(supabaseURL);
    const rawPrefix = `${base.origin}${SIGNED_ROUTE}`;
    if (!suppliedURL.startsWith(rawPrefix)) return null;
    const rawPathAndQuery = suppliedURL.slice(rawPrefix.length);
    const rawPath = rawPathAndQuery.split(/[?#]/, 1)[0];
    if (rawPath.split("/").some((segment) => segment === "." || segment === "..")) return null;
    const supplied = new URL(suppliedURL);
    if (base.protocol !== "https:" || supplied.protocol !== "https:") return null;
    if (supplied.origin !== base.origin || supplied.hash) return null;
    const token = supplied.searchParams.get("token") ?? "";
    if (!/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(token)) return null;
    if (!supplied.pathname.startsWith(SIGNED_ROUTE)) return null;
    if (!rawPath || /%(2f|5c|25)/i.test(rawPath) || rawPath.includes("\\")) return null;

    const rawSegments = rawPath.split("/");
    if (rawSegments.length !== 3 || rawSegments.some((segment) => !segment)) return null;
    const segments = rawSegments.map((segment) => decodeURIComponent(segment));
    if (segments.some((segment) => segment === "." || segment === ".." ||
      segment.includes("/") || segment.includes("\\") || segment.includes("\0"))) return null;
    if (segments[0] !== uid || segments[1] !== "support") return null;

    const encodedPath = segments.map(encodeURIComponent).join("/");
    // Re-encoding once must produce the exact path. This rejects double encoding
    // and non-canonical aliases that different routers could interpret differently.
    if (encodedPath !== rawPath) return null;
    const objectPath = segments.join("/");
    return {
      objectPath,
      downloadURL: `${base.origin}/storage/v1/object/authenticated/user-media/${encodedPath}`,
      uploadURL: `${base.origin}/storage/v1/object/user-media/${encodedPath}`,
      signURL: `${base.origin}/storage/v1/object/sign/user-media/${encodedPath}`,
    };
  } catch {
    return null;
  }
}

/// Downloads only the trusted Storage API URL and refuses redirects. The caller
/// decides whether the returned bytes decode as an accepted image.
export async function fetchTrustedSupportMedia(
  media: TrustedSupportMedia,
  serviceKey: string,
  fetcher: FetchLike = fetch,
): Promise<Uint8Array> {
  const response = await fetcher(media.downloadURL, {
    headers: { authorization: `Bearer ${serviceKey}`, apikey: serviceKey },
    redirect: "error",
    signal: AbortSignal.timeout(5_000),
  });
  if (!response.ok || response.redirected) {
    throw new Error(`support media download failed (${response.status})`);
  }
  const declared = Number(response.headers.get("content-length") ?? "0");
  if (Number.isFinite(declared) && declared > SUPPORT_MEDIA_MAX_BYTES) {
    throw new Error("support media download is too large");
  }
  if (!response.body) return new Uint8Array();
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > SUPPORT_MEDIA_MAX_BYTES) {
      await reader.cancel("support media download is too large");
      throw new Error("support media download is too large");
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return bytes;
}

/// Reads dimensions from the formats accepted by the server-side decoder before
/// full decode, rejecting malformed/unsupported inputs and decompression bombs.
export function rasterWithinPixelBudget(bytes: Uint8Array): boolean {
  const dimensions = pngDimensions(bytes) ?? jpegDimensions(bytes);
  if (!dimensions) return false;
  const [width, height] = dimensions;
  return width > 0 && height > 0 && width * height <= SUPPORT_MEDIA_MAX_PIXELS;
}

function pngDimensions(bytes: Uint8Array): [number, number] | null {
  if (bytes.length < 24 || bytes[0] !== 0x89 || bytes[1] !== 0x50 ||
    bytes[2] !== 0x4e || bytes[3] !== 0x47) return null;
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  return [view.getUint32(16), view.getUint32(20)];
}

function jpegDimensions(bytes: Uint8Array): [number, number] | null {
  if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8) return null;
  let offset = 2;
  let dimensions: [number, number] | null = null;
  while (offset + 1 < bytes.length) {
    // Marker grammar is strict before the scan: arbitrary bytes cannot be
    // skipped in search of a convenient fake SOF.
    if (bytes[offset] !== 0xff) return null;
    while (offset < bytes.length && bytes[offset] === 0xff) offset += 1;
    if (offset >= bytes.length) return null;
    const marker = bytes[offset];
    offset += 1;
    if (marker === 0x00) return null;
    if (marker === 0xd9) return null;
    if (marker === 0xd8 || marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
    if (offset + 2 > bytes.length) return null;
    const length = (bytes[offset] << 8) | bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length) return null;
    if (marker === 0xda) return dimensions;
    if ((marker >= 0xc0 && marker <= 0xc3) || (marker >= 0xc5 && marker <= 0xc7) ||
      (marker >= 0xc9 && marker <= 0xcb) || (marker >= 0xcd && marker <= 0xcf)) {
      if (dimensions || length < 8) return null;
      const height = (bytes[offset + 3] << 8) | bytes[offset + 4];
      const width = (bytes[offset + 5] << 8) | bytes[offset + 6];
      const components = bytes[offset + 7];
      if (length !== 8 + 3 * components) return null;
      dimensions = [width, height];
    }
    offset += length;
  }
  return null;
}

/// Creates the URL that is actually persisted and relayed after sanitization.
/// The caller-supplied signature is never reused.
export async function createFreshSignedSupportURL(
  media: TrustedSupportMedia,
  serviceKey: string,
  fetcher: FetchLike = fetch,
): Promise<string> {
  const response = await fetcher(media.signURL, {
    method: "POST",
    headers: {
      authorization: `Bearer ${serviceKey}`,
      apikey: serviceKey,
      "content-type": "application/json",
    },
    redirect: "error",
    body: JSON.stringify({ expiresIn: 60 * 60 * 24 * 365 }),
    signal: AbortSignal.timeout(5_000),
  });
  if (!response.ok || response.redirected) {
    throw new Error(`support media signing failed (${response.status})`);
  }
  const body = await response.json();
  if (typeof body?.signedURL !== "string") throw new Error("support media signing returned invalid data");
  const absolute = new URL(body.signedURL, new URL(media.signURL).origin).href;
  if (!trustedSupportMedia(new URL(media.signURL).origin, absolute, media.objectPath.split("/")[0])) {
    throw new Error("support media signing returned invalid data");
  }
  return absolute;
}
