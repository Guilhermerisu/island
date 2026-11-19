import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';

const Todos = {};
runInNewContext(readFileSync(new URL('../addons/todos/Todos.js', import.meta.url), 'utf8'), Todos);

test('opens both Priority Todos formats and preserves status, notes, dates and last tab', () => {
  const previousTasks = [{ id: 'one', title: 'Algebra', description: 'Read the problem\nList what is given',
    priority: 'high', completed: true, createdAt: 1, completedAt: 2 }];
  const old = Todos.parseStore(JSON.stringify(previousTasks));
  assert.equal(old.tasks[0].status, 'complete');
  assert.equal(old.activeTab, 'ongoing');

  const original = Todos.parseStore(JSON.stringify({ version: 1, activeTab: 'complete', tasks: previousTasks }));
  const json = JSON.parse(Todos.serialize(original.tasks, original.activeTab));
  assert.equal(json.activeTab, 'complete');
  assert.deepEqual(json.tasks, [{ ...previousTasks[0], status: 'complete' }]);
  assert.equal(Todos.parseStore('{ unfinished'), null);
  assert.equal(Todos.parseStore('{}'), null);
});

test('sorts, searches, edits and moves tasks using the existing priority rules', () => {
  const easy = Todos.createTask('History', 'Read page 12', 'low', 'ongoing');
  const urgent = Todos.createTask('Algebra', 'Open the worksheet', 'critical', 'backlog');
  let tasks = [easy, urgent];
  tasks = Todos.setStatus(tasks, urgent.id, 'ongoing');
  assert.deepEqual(Array.from(Todos.listed(tasks, '', 'ongoing'), task => task.title), ['Algebra', 'History']);
  assert.equal(Todos.highestOngoing(tasks), 'critical');
  assert.equal(Todos.listed(tasks, 'WORKSHEET', 'ongoing')[0].id, urgent.id);
  assert.equal(Todos.listed(tasks, 'критическая', 'ongoing', text => text === 'Critical' ? 'Критическая' : text)[0].id, urgent.id);

  tasks = Todos.updateTask(tasks, urgent.id, 'Algebra 327', 'List what is given', 'high');
  tasks = Todos.setStatus(tasks, urgent.id, 'complete');
  const completed = Todos.listed(tasks, '', 'complete')[0];
  assert.equal(completed.title, 'Algebra 327');
  assert.ok(completed.completedAt > 0);
  assert.equal(Todos.removeCompleted(tasks).length, 1);
  assert.equal(Todos.setStatus(tasks, urgent.id, 'ongoing')[1].completedAt, 0);
  assert.equal(Todos.remove(tasks, urgent.id).length, 1);
});
