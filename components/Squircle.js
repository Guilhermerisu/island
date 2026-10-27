.pragma library

// SVG path for a rectangle with Apple-style continuous ("squircle") corners,
// after Figma's corner smoothing (MartinRGB / figma-squircle). The curve eases
// into each corner along the edge instead of meeting a circular arc abruptly.
// `smoothing` is 0 (plain circular) to 1; 0.6 matches iOS and macOS. Corners
// without room to smooth (a capsule's ends) fall back to circular arcs.
function corner(radius, smoothing, budget) {
  var r = Math.max(0, Math.min(radius, budget))
  var p = (1 + smoothing) * r
  if (p > budget) {
    smoothing = Math.max(0, Math.min(smoothing, budget / Math.max(r, 0.001) - 1))
    p = Math.min(p, budget)
  }
  var rad = Math.PI / 180
  var arcMeasure = 90 * (1 - smoothing)
  var arc = Math.sin(arcMeasure / 2 * rad) * r * Math.SQRT2
  var alpha = (90 - arcMeasure) / 2
  var p3ToP4 = r * Math.tan(alpha / 2 * rad)
  var beta = 45 * smoothing
  var c = p3ToP4 * Math.cos(beta * rad)
  var d = c * Math.tan(beta * rad)
  var b = (p - arc - c - d) / 3
  return { r: r, p: p, a: 2 * b, b: b, c: c, d: d, arc: arc }
}

function path(width, height, radii, smoothing) {
  var w = Math.max(0, width), h = Math.max(0, height)
  var budget = Math.min(w, h) / 2
  var tl = corner(radii.topLeft, smoothing, budget)
  var tr = corner(radii.topRight, smoothing, budget)
  var br = corner(radii.bottomRight, smoothing, budget)
  var bl = corner(radii.bottomLeft, smoothing, budget)
  function f(n) { return n.toFixed(2) }
  var s = "M " + f(w - tr.p) + " 0 "
  if (tr.r > 0) s += "c " + f(tr.a) + " 0 " + f(tr.a + tr.b) + " 0 " + f(tr.a + tr.b + tr.c) + " " + f(tr.d)
    + " a " + f(tr.r) + " " + f(tr.r) + " 0 0 1 " + f(tr.arc) + " " + f(tr.arc)
    + " c " + f(tr.d) + " " + f(tr.c) + " " + f(tr.d) + " " + f(tr.b + tr.c) + " " + f(tr.d) + " " + f(tr.a + tr.b + tr.c) + " "
  s += "L " + f(w) + " " + f(h - br.p) + " "
  if (br.r > 0) s += "c 0 " + f(br.a) + " 0 " + f(br.a + br.b) + " " + f(-br.d) + " " + f(br.a + br.b + br.c)
    + " a " + f(br.r) + " " + f(br.r) + " 0 0 1 " + f(-br.arc) + " " + f(br.arc)
    + " c " + f(-br.c) + " " + f(br.d) + " " + f(-(br.b + br.c)) + " " + f(br.d) + " " + f(-(br.a + br.b + br.c)) + " " + f(br.d) + " "
  s += "L " + f(bl.p) + " " + f(h) + " "
  if (bl.r > 0) s += "c " + f(-bl.a) + " 0 " + f(-(bl.a + bl.b)) + " 0 " + f(-(bl.a + bl.b + bl.c)) + " " + f(-bl.d)
    + " a " + f(bl.r) + " " + f(bl.r) + " 0 0 1 " + f(-bl.arc) + " " + f(-bl.arc)
    + " c " + f(-bl.d) + " " + f(-bl.c) + " " + f(-bl.d) + " " + f(-(bl.b + bl.c)) + " " + f(-bl.d) + " " + f(-(bl.a + bl.b + bl.c)) + " "
  s += "L 0 " + f(tl.p) + " "
  if (tl.r > 0) s += "c 0 " + f(-tl.a) + " 0 " + f(-(tl.a + tl.b)) + " " + f(tl.d) + " " + f(-(tl.a + tl.b + tl.c))
    + " a " + f(tl.r) + " " + f(tl.r) + " 0 0 1 " + f(tl.arc) + " " + f(-tl.arc)
    + " c " + f(tl.c) + " " + f(-tl.d) + " " + f(tl.b + tl.c) + " " + f(-tl.d) + " " + f(tl.a + tl.b + tl.c) + " " + f(-tl.d) + " "
  return s + "Z"
}

function notchPath(width, height, radius, earRadius, smoothing) {
  var w = Math.max(0, width), h = Math.max(0, height)
  var budget = Math.min(w, h) / 2
  var br = corner(radius, smoothing, budget)
  var bl = corner(radius, smoothing, budget)
  function f(n) { return n.toFixed(2) }
  var er = earRadius || 10
  var s = "M " + f(w) + " " + f(er) + " "
  s += "L " + f(w) + " " + f(h - br.p) + " "
  if (br.r > 0) {
    s += "c 0 " + f(br.a) + " 0 " + f(br.a + br.b) + " " + f(-br.d) + " " + f(br.a + br.b + br.c)
      + " a " + f(br.r) + " " + f(br.r) + " 0 0 1 " + f(-br.arc) + " " + f(br.arc)
      + " c " + f(-br.c) + " " + f(br.d) + " " + f(-(br.b + br.c)) + " " + f(br.d) + " " + f(-(br.a + br.b + br.c)) + " " + f(br.d) + " "
  }
  s += "L " + f(bl.p) + " " + f(h) + " "
  if (bl.r > 0) {
    s += "c " + f(-bl.a) + " 0 " + f(-(bl.a + bl.b)) + " 0 " + f(-(bl.a + bl.b + bl.c)) + " " + f(-bl.d)
      + " a " + f(bl.r) + " " + f(bl.r) + " 0 0 1 " + f(-bl.arc) + " " + f(-bl.arc)
      + " c " + f(-bl.d) + " " + f(-bl.c) + " " + f(-bl.d) + " " + f(-(bl.b + bl.c)) + " " + f(-bl.d) + " " + f(-(bl.a + bl.b + bl.c)) + " "
  }
  s += "L 0 " + f(er)
  return s
}

