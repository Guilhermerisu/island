export const indicators = [
  { id: "recording", label: "Screen Recording", icon: "󰑊", color: "#ff453a" },
  { id: "meetings", label: "Meetings", icon: "󰏲", color: "#30d158" },
  { id: "timer", label: "Timer", icon: "󰔛", color: "#ff9f0a" },
  { id: "agents", label: "Agent Activity", icon: "󰚩", color: "#bf8af6" },
  { id: "downloads", label: "Downloads", icon: "󰇚", color: "#64d2ff" },
  { id: "updates", label: "System Updates", icon: "󰚰", color: "#0a84ff" },
  { id: "video", label: "Watching Video", icon: "󰕧", color: "#ff6961" },
  { id: "music", label: "Listening to Music", icon: "󰝚", color: "#5e5ce6" }
];

export const defaultOrder = indicators.map(indicator => indicator.id);

export function normalizeOrder(saved) {
  const order = [];
  for (const value of saved.split(",")) {
    const id = value.trim();
    if (defaultOrder.includes(id) && !order.includes(id)) order.push(id);
  }
  return order.concat(defaultOrder.filter(id => !order.includes(id)));
}

export function moveIndicator(order, id, offset) {
  const from = order.indexOf(id);
  const to = from + offset;
  if (from === -1 || to < 0 || to >= order.length || from === to) return order;
  const next = order.slice();
  next.splice(from, 1);
  next.splice(to, 0, id);
  return next;
}

export function selectIndicator(order, available, confirmation) {
  return confirmation || order.find(id => available.includes(id)) || available[0] || "";
}

function domainOf(url) {
  return /^(?:https?:)?\/\/([^/:?#]+)(?:[/:?#]|$)/i.exec(url)?.[1]?.toLowerCase() || "";
}

function onDomain(host, domain) {
  return host === domain || host.endsWith("." + domain);
}

export function mediaKind(metadata, art, source) {
  const url = String(metadata?.["xesam:url"] || "");
  const domain = domainOf(url);
  const file = url.split(/[?#]/, 1)[0].toLowerCase();
  const mime = String(metadata?.["xesam:mimeType"] || "").toLowerCase();
  if (onDomain(domain, "music.youtube.com") || onDomain(domain, "spotify.com") || mime.startsWith("audio/"))
    return "music";
  if (mime.startsWith("video/") || /\.(mp4|mkv|webm|mov|avi|m4v|mpg|mpeg|ogv)$/.test(file)
      || ["youtube.com", "youtu.be", "twitch.tv", "vimeo.com", "netflix.com", "vkvideo.ru", "rutube.ru"]
        .some(site => onDomain(domain, site)))
    return "video";
  if (/\.(mp3|flac|wav|ogg|opus|m4a|aac|aiff|alac)$/.test(file)
      || metadata?.["xesam:album"]
      || /(?:^|[.\s-])(spotify|rhythmbox|elisa|audacious|amberol|clementine|strawberry)(?:$|[.\s-])/i.test(source))
    return "music";
  return onDomain(domainOf(art), "ytimg.com") ? "video" : "";
}

export function browserTabKind(trackTitle, windowTitle) {
  const track = trackTitle.trim().toLowerCase();
  const title = windowTitle.trim().toLowerCase();
  if (!track || !title.startsWith(track)) return "";
  const suffix = title.slice(track.length);
  if (!/^\s+[-–—|]\s+/.test(suffix)) return "";
  if (/\b(youtube music|spotify)\b/.test(suffix)) return "music";
  if (/\b(youtube|twitch|netflix|vimeo|rutube)\b/.test(suffix)) return "video";
  return "";
}
