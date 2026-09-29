import { rasterWithinPixelBudget, SUPPORT_MEDIA_MAX_BYTES } from "./support-media.ts";

export interface SupportAttachmentKind {
  mime: string;
  image: boolean;
}

// Match the app's file picker. Never trust the caller's MIME or permit active
// web content/executables merely because they were uploaded to private Storage.
export function supportAttachmentKind(bytes: Uint8Array, objectPath: string): SupportAttachmentKind | null {
  if (!bytes.length || bytes.length > SUPPORT_MEDIA_MAX_BYTES) return null;
  const extension = objectPath.split(".").pop()?.toLowerCase();
  if (["jpg", "jpeg", "png"].includes(extension ?? "")) {
    return rasterWithinPixelBudget(bytes) ? { mime: "image/jpeg", image: true } : null;
  }
  const ascii = (start: number, end: number) => String.fromCharCode(...bytes.subarray(start, end));
  if (extension === "pdf" && ascii(0, 5) === "%PDF-" &&
      new TextDecoder().decode(bytes.subarray(Math.max(0, bytes.length - 1024))).includes("%%EOF")) {
    return { mime: "application/pdf", image: false };
  }
  if (extension === "txt") {
    try {
      const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
      if (!/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/.test(text)) {
        return { mime: "text/plain", image: false };
      }
    } catch { /* Not UTF-8 text. */ }
    return null;
  }
  if (extension === "wav" && bytes.length >= 44 && ascii(0, 4) === "RIFF" && ascii(8, 12) === "WAVE") {
    return { mime: "audio/wav", image: false };
  }
  if (extension === "mp3" && bytes.length >= 4 &&
      (ascii(0, 3) === "ID3" || (bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0 &&
        (bytes[1] & 0x06) !== 0 && (bytes[2] & 0xf0) !== 0xf0))) {
    return { mime: "audio/mpeg", image: false };
  }
  if (extension === "aac" && bytes.length >= 7 && bytes[0] === 0xff && (bytes[1] & 0xf6) === 0xf0) {
    return { mime: "audio/aac", image: false };
  }
  if (extension === "m4a" && isAudioMP4(bytes)) return { mime: "audio/mp4", image: false };
  return null;
}

interface Box { type: string; start: number; end: number }

function boxes(bytes: Uint8Array, start: number, end: number): Box[] | null {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const result: Box[] = [];
  while (start < end) {
    if (end - start < 8) return null;
    const size = view.getUint32(start);
    // Large-size boxes are unnecessary inside this 10 MB bounded format.
    if (size === 1 || (size !== 0 && size < 8)) return null;
    const next = size === 0 ? end : start + size;
    if (next > end) return null;
    result.push({ type: String.fromCharCode(...bytes.subarray(start + 4, start + 8)), start: start + 8, end: next });
    start = next;
  }
  return result;
}

function isAudioMP4(bytes: Uint8Array): boolean {
  const top = boxes(bytes, 0, bytes.length);
  if (!top?.some((box) => box.type === "ftyp" && box.end - box.start >= 8) ||
      !top.some((box) => box.type === "mdat")) return false;
  const movie = top.find((box) => box.type === "moov");
  if (!movie) return false;
  const tracks = boxes(bytes, movie.start, movie.end)?.filter((box) => box.type === "trak");
  if (!tracks?.length) return false;
  return tracks.every((track) => {
    const media = boxes(bytes, track.start, track.end)?.find((box) => box.type === "mdia");
    if (!media) return false;
    const handler = boxes(bytes, media.start, media.end)?.find((box) => box.type === "hdlr");
    return !!handler && handler.end - handler.start >= 12 &&
      String.fromCharCode(...bytes.subarray(handler.start + 8, handler.start + 12)) === "soun";
  });
}
