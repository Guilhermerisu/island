import assert from 'node:assert/strict';
import { test } from 'node:test';
import { bypassDoNotDisturb, incomingCall } from '../companion/guilhermerisu.notifications/DiscordCall.mjs';

test('recognizes incoming calls and preserves the sender action index', () => {
  assert.deepEqual(incomingCall({ app: 'Vesktop', category: 'call.incoming', summary: 'Alice',
    actions: [{ label: 'Decline' }, { id: 'accept-call' }] }), { name: 'Alice', accept: 1 });
  assert.deepEqual(incomingCall({ app: 'Discord', summary: 'Оля звонит вам' }), { name: 'Оля', accept: -1 });
  assert.deepEqual(incomingCall({ app: 'Chromium', summary: 'Discord', body: 'Incoming call from Chris' }),
    { name: 'Chris', accept: -1 });
});

test('bypasses Do Not Disturb only for calls while the exception is enabled', () => {
  const call = { appName: 'Discord', summary: 'Alice', hints: { category: 'call.incoming' } };
  assert.equal(bypassDoNotDisturb(call, true), true);
  assert.equal(bypassDoNotDisturb(call, false), false);
  assert.equal(bypassDoNotDisturb({ ...call, hints: {}, body: 'Hello' }, true), false);
});

test('leaves ordinary messages, missed calls and other apps alone', () => {
  assert.equal(incomingCall({ app: 'Discord', summary: 'Alice', body: 'I am calling later' }), null);
  assert.equal(incomingCall({ app: 'Discord', category: 'call.ended', summary: 'Missed call' }), null);
  assert.equal(incomingCall({ app: 'Slack', summary: 'Alice is calling you' }), null);
});
