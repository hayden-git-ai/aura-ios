import assert from "node:assert/strict";
import test from "node:test";

import {
  checkedArrayPages,
  checkedFetch,
  checkedFetchChunks,
  type FetchLike,
} from "./checked-fetch.ts";

test("checkedFetch returns a successful response without outbound I/O", async () => {
  let calls = 0;
  const stub: FetchLike = async () => {
    calls += 1;
    return new Response(null, { status: 204 });
  };

  const response = await checkedFetch("test request", "https://invalid.local", {}, stub);

  assert.equal(response.status, 204);
  assert.equal(calls, 1);
});

test("checkedFetch rejects a sanitized non-success status", async () => {
  const stub: FetchLike = async () => new Response("private backend detail", { status: 503 });

  await assert.rejects(
    checkedFetch("support message insert", "https://invalid.local", {}, stub),
    { message: "support message insert failed (503)" },
  );
});

test("checkedArrayPages advances offsets and stops after the short page", async () => {
  const offsets: number[] = [];
  const pages = new Map<number, number[]>([[0, [1, 2]], [2, [3]]]);
  const stub: FetchLike = async (_input, init) => {
    const offset = Number(JSON.parse(String(init?.body)).offset);
    offsets.push(offset);
    return Response.json(pages.get(offset));
  };

  const values = await checkedArrayPages<number>(
    "storage list",
    2,
    (offset) => ({
      input: "https://invalid.local",
      init: { method: "POST", body: JSON.stringify({ offset }) },
    }),
    stub,
  );

  assert.deepEqual(values, [1, 2, 3]);
  assert.deepEqual(offsets, [0, 2]);
});

test("checkedArrayPages rejects invalid JSON shape", async () => {
  const stub: FetchLike = async () => Response.json({ rows: [] });

  await assert.rejects(
    checkedArrayPages("storage list", 2, () => ({ input: "https://invalid.local" }), stub),
    { message: "storage list returned invalid data" },
  );
});

test("checkedFetchChunks splits 1001 values into 1000 and 1", async () => {
  const chunkLengths: number[] = [];
  const stub: FetchLike = async (_input, init) => {
    chunkLengths.push(JSON.parse(String(init?.body)).prefixes.length);
    return new Response(null, { status: 204 });
  };
  const paths = Array.from({ length: 1001 }, (_, index) => `user/${index}.jpg`);

  await checkedFetchChunks(
    "user media delete",
    paths,
    1000,
    (chunk) => ({
      input: "https://invalid.local",
      init: { method: "DELETE", body: JSON.stringify({ prefixes: chunk }) },
    }),
    stub,
  );

  assert.deepEqual(chunkLengths, [1000, 1]);
});

test("checkedFetchChunks rejects when a later chunk fails", async () => {
  let calls = 0;
  const stub: FetchLike = async () => {
    calls += 1;
    return new Response(null, { status: calls === 2 ? 503 : 204 });
  };

  await assert.rejects(
    checkedFetchChunks(
      "user media delete",
      [1, 2, 3],
      2,
      () => ({ input: "https://invalid.local", init: { method: "DELETE" } }),
      stub,
    ),
    { message: "user media delete failed (503)" },
  );
  assert.equal(calls, 2);
});
