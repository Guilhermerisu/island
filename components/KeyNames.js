.pragma library

// How a Hyprland key name reads on a keycap, shared by Settings' Keybinds
// page and the Keybindings list: "SUPER" → "Super", "RETURN" → "Enter",
// "COMMA" → ",". Names are title case, never all caps; a single letter or
// digit and F1–F24 stay as they are, and a name that already has lowercase
// (XF86AudioMute, mouse_down) is left alone.
var names = {
  SUPER: "Super", SHIFT: "Shift", CTRL: "Ctrl", ALT: "Alt",
  ESCAPE: "Esc", RETURN: "Enter", BACKSPACE: "Backspace", PRIOR: "Page Up", NEXT: "Page Down",
  COMMA: ",", PERIOD: ".", SLASH: "/", MINUS: "-", EQUAL: "=", GRAVE: "`", SEMICOLON: ";",
  APOSTROPHE: "'", BRACKETLEFT: "[", BRACKETRIGHT: "]", BACKSLASH: "\\"
}

function key(part) {
  part = String(part || "").trim()
  if (Object.prototype.hasOwnProperty.call(names, part)) return names[part]
  if (part.length <= 1 || /^F\d{1,2}$/.test(part) || /[a-z]/.test(part)) return part
  return part.charAt(0) + part.slice(1).toLowerCase()
}

// "SUPER + SHIFT + RETURN" → "Super + Shift + Enter"; "None" when empty.
function shortcut(keys) {
  if (!keys) return "None"
  return String(keys).split(" + ").map(key).join(" + ")
}
