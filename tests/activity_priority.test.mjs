import assert from "node:assert/strict";
import test from "node:test";
import { browserTabKind, defaultOrder, mediaKind, moveIndicator, normalizeOrder, selectIndicator } from "../services/ActivityPriority.mjs";

test("an empty priority preference uses the default", () => {
  assert.deepEqual(normalizeOrder(""), defaultOrder);
  assert.deepEqual(normalizeOrder(defaultOrder.join(",")), defaultOrder);
});

test("saved priorities keep their order and recover missing categories", () => {
  const order = normalizeOrder("video,removed,timer,video");
  assert.deepEqual(order.slice(0, 2), ["video", "timer"]);
  assert.equal(order.length, defaultOrder.length);
  assert.equal(new Set(order).size, order.length);
  assert.deepEqual(moveIndicator(order, "timer", -1).slice(0, 2), ["timer", "video"]);
  assert.equal(moveIndicator(order, "video", -1), order);
});

test("availability and urgent confirmations decide which indicator is shown", () => {
  const order = normalizeOrder("video,timer,music,agents,updates,downloads");
  assert.equal(selectIndicator(order, ["agents", "timer", "video"]), "video");
  assert.equal(selectIndicator(order, ["agents", "timer"]), "timer");
  assert.equal(selectIndicator(order, ["downloads", "updates"]), "updates");
  assert.equal(selectIndicator(order, ["music", "agents"], "displays"), "displays");
  assert.equal(selectIndicator(order, []), "");
});

test("music and video use media metadata or the matching browser tab", () => {
  assert.equal(mediaKind({ "xesam:url": "https://www.youtube.com/watch?v=abc" }), "video");
  assert.equal(mediaKind({ "xesam:url": "https://music.youtube.com/watch?v=abc" }), "music");
  assert.equal(mediaKind({ "xesam:url": "file:///tmp/sample.mkv" }), "video");
  assert.equal(mediaKind({ "xesam:url": "file:///tmp/sample.flac" }), "music");
  assert.equal(mediaKind({}, "", "org.mpris.MediaPlayer2.spotify"), "music");
  assert.equal(mediaKind({}, "https://i.ytimg.com/vi/abc/thumbnail.jpg", "chromium"), "video");
  assert.equal(mediaKind({}, "", "chromium"), "");
  assert.equal(browserTabKind("Test", "Test - YouTube Music — Chromium"), "music");
  assert.equal(browserTabKind("Test", "Test - YouTube — Firefox"), "video");
  assert.equal(browserTabKind("Test", "Tester - YouTube — Firefox"), "");
});
