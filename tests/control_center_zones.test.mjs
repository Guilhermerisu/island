import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';

const Zones = {};
const source = readFileSync(new URL('../views/control-center/zones.js', import.meta.url), 'utf8');
runInNewContext(source.replace(/^\.pragma library\n/, ''), Zones);

const known = ['controls', 'activities', 'notifications'];
const layout = (raw, columns = 2) => Zones.normalize(raw, columns, known);
const plain = model => JSON.parse(JSON.stringify(model));

test('places activities beside their previous controls on an existing layout', () => {
  assert.deepEqual(plain(layout('[["notifications"],["controls"]]')),
    [['notifications'], ['controls', 'activities']]);
  assert.deepEqual(plain(layout('[["notifications"],[]]')),
    [['notifications', 'activities'], []]);
});

test('persists the moved zone and keeps it removed until explicitly added', () => {
  const initial = layout('[["controls","notifications"],[]]');
  const moved = Zones.move(initial, 'activities', 1, 0);
  const saved = Zones.serialize(moved);
  assert.deepEqual(plain(layout(saved)), [['controls', 'notifications'], ['activities']]);
  assert.deepEqual(plain(Zones.unfold(saved, layout(saved, 1))),
    [['controls', 'notifications'], ['activities']]);

  const removed = Zones.serialize(Zones.remove(moved, 'activities'));
  assert.deepEqual(plain(layout(removed)), [['controls', 'notifications'], []]);
  assert.deepEqual(plain(layout(Zones.serialize(Zones.add(layout(removed), 'activities')))),
    [['controls', 'notifications'], ['activities']]);
});
