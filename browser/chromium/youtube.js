let shuffledPlaylist = "";
const shuffledVideos = new Set();

function watchUrl(value) {
  if (!value) return null;
  const url = new URL(value, location.href);
  return url.origin === location.origin && url.pathname === "/watch" && url.searchParams.has("v")
    ? url : null;
}

function normalize(title) {
  return String(title || "").replace(/\s+- YouTube$/, "").replace(/\s+/g, " ").trim();
}

function playerState(title) {
  const url = watchUrl(location.href);
  const video = document.querySelector("#movie_player video");
  const heading = document.querySelector("ytd-watch-metadata h1");
  const matched = title && [heading?.textContent, document.title].some(text => normalize(text) === normalize(title));
  if (!url || !video || !matched) return null;

  const playlist = url.searchParams.get("list") || "";
  const entries = [...document.querySelectorAll("ytd-playlist-panel-renderer ytd-playlist-panel-video-renderer")]
    .map(item => ({ item, link: item.querySelector("a[href]") }))
    .map(({ item, link }) => ({ item, link, url: watchUrl(link?.href) }))
    .filter(entry => playlist && entry.url?.searchParams.get("list") === playlist);
  const current = entries.findIndex(entry => entry.item.hasAttribute("selected"));
  const buttons = document.querySelector("#movie_player");
  const available = button => button && !button.disabled && button.getAttribute("aria-disabled") !== "true"
    && getComputedStyle(button).display !== "none";
  const next = buttons.querySelector(".ytp-next-button");
  const previous = buttons.querySelector(".ytp-prev-button");
  const recommendation = !playlist && [...document.querySelectorAll(
    "#related ytd-compact-video-renderer a[href], #related yt-lockup-view-model a[href]",
  )].find(link => {
    const suggested = watchUrl(link.href);
    return suggested && suggested.searchParams.get("v") !== url.searchParams.get("v");
  });
  const previousEntry = navigation.entries().slice(0, navigation.currentEntry?.index)
    .reverse().find(entry => {
      const previousUrl = watchUrl(entry.url);
      return previousUrl && previousUrl.searchParams.get("v") !== url.searchParams.get("v");
    });
  return {
    url, video, playlist, entries, current, previousEntry,
    next: available(next) ? next : recommendation || null,
    previous: available(previous) ? previous : null,
    shuffle: !!playlist && shuffledPlaylist === playlist,
  };
}

function pickShuffled(state) {
  const currentVideo = state.url.searchParams.get("v");
  shuffledVideos.add(currentVideo);
  const choices = state.entries.filter(entry => !shuffledVideos.has(entry.url.searchParams.get("v")));
  if (!choices.length) return null;
  return choices[Math.floor(Math.random() * choices.length)];
}

function nextShuffled(state) {
  const next = pickShuffled(state);
  if (!next) return false;
  next.link.click();
  return true;
}

chrome.runtime.onMessage.addListener(({ action, title }, _sender, respond) => {
  const state = playerState(title);
  if (!state) return respond({});
  const nextInList = state.current >= 0 ? state.entries[state.current + 1] : null;
  const previousInList = state.current > 0 ? state.entries[state.current - 1] : null;
  if (action === "status") {
    return respond({
      matched: true,
      playing: !state.video.paused && !state.video.ended,
      canNext: !!(state.next || nextInList || (state.shuffle && state.entries.length > 1)),
      canPrevious: !!(state.previous || previousInList || state.previousEntry),
      canShuffle: state.entries.length > 1,
      shuffle: state.shuffle,
    });
  }
  if (action === "shuffle" && state.entries.length > 1) {
    shuffledPlaylist = state.shuffle ? "" : state.playlist;
    shuffledVideos.clear();
    return respond({ ok: true });
  }
  if (action === "next") {
    if (state.shuffle && nextShuffled(state)) return respond({ ok: true });
    const next = nextInList?.link || state.next;
    next?.click();
    return respond({ ok: !!next });
  }
  if (action === "previous") {
    if (state.shuffle && state.previousEntry) {
      navigation.traverseTo(state.previousEntry.key);
      return respond({ ok: true });
    }
    const previous = previousInList?.link || state.previous;
    if (previous) previous.click();
    else if (state.previousEntry) navigation.traverseTo(state.previousEntry.key);
    return respond({ ok: !!(previous || state.previousEntry) });
  }
  respond({});
});

// YouTube handles autoplay at the end of the video. When shuffle has an
// unplayed entry, navigate first and let the next page take over playback.
document.addEventListener("ended", event => {
  if (!shuffledPlaylist) return;
  const state = playerState(document.title);
  if (state?.shuffle && event.target === state.video && nextShuffled(state)) {
    event.stopImmediatePropagation();
  }
}, true);
