import test from 'node:test';
import assert from 'node:assert/strict';

// Exercise the actual request handler with only local stubs. No credentials,
// camera data, provider calls, or Supabase writes are used.
const env = new Map<string, string>();
let handler: (request: Request) => Promise<Response>;
globalThis.Deno = {
  env: { get: (name: string) => env.get(name) },
  serve: (callback: typeof handler) => { handler = callback; },
} as never;
await import('./index.ts');
const originalFetch = globalThis.fetch;
const request = (image = '/9j/2Q==') => new Request('https://local.test/verify-proof', {
  method: 'POST', headers: { 'content-type': 'application/json', 'x-aura-key': 'test-only' },
  body: JSON.stringify({ image, habitName: 'Play an instrument', hint: 'Show the instrument' }),
});

test('disabled verification never calls a provider or returns a pass', async () => {
  env.clear(); env.set('PROOF_DISABLED', 'on');
  globalThis.fetch = async () => { throw new Error('Unexpected outbound I/O'); };
  try {
    const response = await handler(request());
    assert.equal(response.status, 503);
    assert.notEqual((await response.json()).passed, true);
  } finally { globalThis.fetch = originalFetch; }
});

test('malformed, rejected and unavailable verification cannot become success', async () => {
  env.clear(); env.set('AURA_APP_KEY', 'test-only'); env.set('GEMINI_API_KEY', 'test-only');
  let verdict: unknown = { passed: false, reason: 'Unrelated water bottle', fix: 'Show the instrument' };
  globalThis.fetch = async () => new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify(verdict) }] } }] }));
  try {
    const rejected = await handler(request());
    assert.equal(rejected.status, 200);
    assert.equal((await rejected.json()).passed, false);
    verdict = { passed: 'true', reason: '' };
    assert.equal((await handler(request())).status, 502);
    assert.equal((await handler(request('bm90LWEtcGhvdG8='))).status, 415);
    globalThis.fetch = async () => { throw new Error('Provider unavailable'); };
    const unavailable = await handler(request());
    assert.equal(unavailable.status, 502);
    assert.deepEqual(await unavailable.json(), { error: 'photo verification temporarily unavailable' });
  } finally { globalThis.fetch = originalFetch; }
});


test('work-screen evidence exception reaches the provider without weakening physical proof rules', async () => {
  env.clear(); env.set('AURA_APP_KEY', 'test-only'); env.set('GEMINI_API_KEY', 'test-only');
  let sent = '';
  globalThis.fetch = async (_url, init) => {
    sent = String(init?.body);
    return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify({ passed: true, reason: 'your work is ready.', fix: '' }) }] } }] }));
  };
  try {
    const response = await handler(new Request('https://local.test/verify-proof', {
      method: 'POST', headers: { 'content-type': 'application/json', 'x-aura-key': 'test-only' },
      body: JSON.stringify({ image: '/9j/2Q==', habitName: 'Deep Work', hint: 'Show the work or the setup. Screen, desk, or notebook.' }),
    }));
    assert.equal(response.status, 200);
    assert.match(sent, /The screen itself is sufficient evidence/);
    assert.match(sent, /displayed picture\/video of a physical activity/);
    assert.doesNotMatch(sent, /it is a photo of a screen, a screenshot/);
  } finally { globalThis.fetch = originalFetch; }
});


test('approved habit alternatives replace UI tips in the actual provider prompt', async () => {
  env.clear(); env.set('AURA_APP_KEY', 'test-only'); env.set('GEMINI_API_KEY', 'test-only');
  let sent = '';
  globalThis.fetch = async (_url, init) => {
    sent = String(init?.body);
    return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify({ passed: true, reason: 'ready to go.', fix: '' }) }] } }] }));
  };
  try {
    for (const [habitName, expected] of [
      ['Hit the gym', 'gym mirror selfie is sufficient'],
      ['Side Hustle', 'photo of money is sufficient'],
      ['Go for a walk', 'their shoes alone is sufficient'],
      ['Go for a run', 'their shoes alone is sufficient'],
      ['Smile', 'photo showing the user smiling'],
      ['Drink some water', 'person physically drinking water'],
    ]) {
      const response = await handler(new Request('https://local.test/verify-proof', {
        method: 'POST', headers: { 'content-type': 'application/json', 'x-aura-key': 'test-only' },
        body: JSON.stringify({ image: '/9j/2Q==', habitName, hint: 'USER_FACING_TIP_ONLY' }),
      }));
      assert.equal(response.status, 200);
      assert.ok(sent.includes(expected), habitName);
      assert.ok(!sent.includes('USER_FACING_TIP_ONLY'), habitName);
      assert.ok(sent.includes('Each listed alternative is sufficient on its own'));
    }
  } finally { globalThis.fetch = originalFetch; }
});
