import assert from "node:assert/strict";
import test from "node:test";
import { supportAttachmentKind } from "./support-attachment.ts";
import { SUPPORT_MEDIA_MAX_BYTES } from "./support-media.ts";

const text = (value: string) => new TextEncoder().encode(value);
function join(...parts: Uint8Array[]): Uint8Array {
  const output = new Uint8Array(parts.reduce((length, part) => length + part.length, 0));
  let offset = 0;
  for (const part of parts) { output.set(part, offset); offset += part.length; }
  return output;
}
function box(type: string, payload: Uint8Array): Uint8Array {
  const header = new Uint8Array(8);
  new DataView(header.buffer).setUint32(0, 8 + payload.length);
  header.set(text(type), 4);
  return join(header, payload);
}
function mp4(handler: string): Uint8Array {
  return join(box("ftyp", text("M4A \0\0\0\0")), box("mdat", new Uint8Array([1, 2])),
    box("moov", box("trak", box("mdia", box("hdlr", join(new Uint8Array(8), text(handler)))))));
}

test("PDF and UTF-8 text are allowed with matching file extensions", () => {
  assert.equal(supportAttachmentKind(text("%PDF-1.7\n1 0 obj\nendobj\n%%EOF"), "a.pdf")?.mime, "application/pdf");
  assert.equal(supportAttachmentKind(text("Hello\nSupport\t✓"), "a.txt")?.mime, "text/plain");
});

test("rejects unsupported types, renamed binaries and invalid text", () => {
  assert.equal(supportAttachmentKind(text("<svg/>"), "a.svg"), null);
  assert.equal(supportAttachmentKind(text("MZ executable"), "a.pdf"), null);
  assert.equal(supportAttachmentKind(new Uint8Array([0, 1, 2]), "a.txt"), null);
  assert.equal(supportAttachmentKind(new Uint8Array([0xff]), "a.txt"), null);
  assert.equal(supportAttachmentKind(text("%PDF-1.7"), "a.pdf"), null);
});

test("rejects empty and oversized attachments before parsing", () => {
  assert.equal(supportAttachmentKind(new Uint8Array(), "a.txt"), null);
  assert.equal(supportAttachmentKind(new Uint8Array(SUPPORT_MEDIA_MAX_BYTES + 1), "a.txt"), null);
});

test("M4A accepts audio tracks and rejects video or malformed box bounds", () => {
  assert.equal(supportAttachmentKind(mp4("soun"), "note.m4a")?.mime, "audio/mp4");
  assert.equal(supportAttachmentKind(mp4("vide"), "video.m4a"), null);
  const invalid = mp4("soun");
  new DataView(invalid.buffer).setUint32(0, invalid.length + 100);
  assert.equal(supportAttachmentKind(invalid, "note.m4a"), null);
  assert.equal(supportAttachmentKind(text("fake ftyp soun"), "note.m4a"), null);
});

test("audio formats require format headers and matching extensions", () => {
  const wav = new Uint8Array(44);
  wav.set(text("RIFF")); wav.set(text("WAVE"), 8);
  assert.equal(supportAttachmentKind(wav, "note.wav")?.mime, "audio/wav");
  assert.equal(supportAttachmentKind(text("ID3\0audio"), "note.mp3")?.mime, "audio/mpeg");
  assert.equal(supportAttachmentKind(new Uint8Array([0xff, 0xf1, 0x50, 0, 0, 0, 0]), "note.aac")?.mime, "audio/aac");
  assert.equal(supportAttachmentKind(text("<html>not audio</html>"), "note.m4a"), null);
  assert.equal(supportAttachmentKind(wav, "note.pdf"), null);
});
