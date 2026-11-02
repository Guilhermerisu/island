.pragma library
.import Quickshell as Qs

// An image source for an icon as apps and notifications give it: a URL as
// is, an absolute path as a file URL, or else a name from the icon theme
// ("" when the theme has none).
function source(icon) {
  var value = String(icon || "")
  if (!value) return ""
  // A file behind the icon provider ("image://icon//home/…") is read as a
  // file, so a deleted one fails (and falls back) instead of the provider's
  // magenta placeholder.
  if (value.indexOf("image://icon//") === 0) return "file://" + value.slice("image://icon/".length)
  if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
  if (value.charAt(0) === "/") return "file://" + value
  return Qs.Quickshell.iconPath(value, true)
}
