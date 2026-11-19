// Adapted from omarchy-cava-widget (https://github.com/twodogsdave/omarchy-cava-widget).
//
// MIT License
//
// Copyright (c) 2026 Dave Brown
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
import QtQuick
import Quickshell
import Quickshell.Io

// Share one capture process, only while an on-screen wave needs it.
Item {
  id: root

  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
    ? Quickshell.env("XDG_RUNTIME_DIR") + "/guilhermerisu-island-cava" : ""
  readonly property string configPath: runtimeDir + "/config"

  property bool wanted: false
  readonly property int bars: 10
  readonly property int framerate: 30
  property var levels: []
  property bool available: false
  property bool playing: false
  property string lastError: ""
  property bool stopping: false

  onWantedChanged: {
    if (wanted) {
      release.stop()
      start()
    } else {
      backoff.stop()
      if (cavaProc.running) release.restart()
    }
  }

  function start() {
    if (wanted && runtimeDir && !stopping && !backoff.running && !cavaProc.running)
      cavaProc.running = true
  }

  function clear() {
    silenceTimer.stop()
    playing = false
    available = false
    levels = []
  }

  function configText() {
    return "[general]\n"
      + "framerate = " + framerate + "\n"
      + "bars = " + bars + "\n"
      + "autosens = 1\n"
      + "sensitivity = 100\n"
      + "lower_cutoff_freq = 50\n"
      + "higher_cutoff_freq = 10000\n"
      + "sleep_timer = 3\n"
      + "\n"
      + "[output]\n"
      + "method = raw\n"
      + "raw_target = /dev/stdout\n"
      + "data_format = ascii\n"
      + "ascii_max_range = 1000\n"
      + "bar_delimiter = 59\n"
      + "frame_delimiter = 10\n"
      + "channels = mono\n"
      + "\n"
      + "[smoothing]\n"
      + "monstercat = 0\n"
      + "waves = 0\n"
      + "noise_reduction = 77\n"
  }

  function parseFrame(line) {
    var parts = String(line).split(";")
    var next = []
    var loud = false
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] === "") continue
      var n = Number(parts[i])
      if (!isFinite(n)) n = 0
      var level = Math.max(0, Math.min(1, n / 1000))
      next.push(level)
      if (level >= 0.03) loud = true
    }
    if (next.length === 0) return
    // Valid frames mark a recovered process and reset the retry delay.
    if (!available) {
      lastError = ""
      backoff.interval = 1000
      available = true
    }
    levels = next
    if (loud) {
      playing = true
      silenceTimer.restart()
    }
  }

  Timer {
    id: silenceTimer
    interval: 450
    onTriggered: root.playing = false
  }

  // Switching between surfaces or briefly pausing keeps the stream warm.
  Timer {
    id: release
    interval: 900
    onTriggered: {
      if (root.wanted || !cavaProc.running) return
      root.stopping = true
      cavaProc.running = false
      root.clear()
    }
  }

  Timer {
    id: backoff
    interval: 1000
    onTriggered: {
      interval = Math.min(8000, interval * 2)
      root.start()
    }
  }

  Process {
    id: cavaProc
    command: ["sh", "-c",
      'mkdir -p -- "$1" && printf "%s" "$3" > "$2" && exec cava -p "$2"',
      "cava", root.runtimeDir, root.configPath, root.configText()]
    stdout: SplitParser {
      onRead: function(line) { if (!root.stopping) root.parseFrame(line) }
    }
    stderr: SplitParser {
      onRead: function(line) {
        var text = String(line).trim()
        if (text) root.lastError = text
      }
    }
    onExited: function(code) {
      var expected = root.stopping
      root.stopping = false
      root.clear()
      if (!root.wanted) return
      if (expected) {
        Qt.callLater(root.start)
      } else {
        if (!root.lastError) root.lastError = "cava exited (" + code + ")"
        if (code !== 127) backoff.start()
      }
    }
  }
}
