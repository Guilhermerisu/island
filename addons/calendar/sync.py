#!/usr/bin/env python3
"""Calendar sync helper for the Island calendar addon.

Fetches the ICS feeds set in the addon's options and parses them, with TZID
timezones and RRULE / EXDATE / RECURRENCE-ID expansion, keeping the last good
reading of each feed in a local cache. Uses Python 3 standard library only.

  sync.py cache               the cached events, for an instant start
  sync.py fetch --ics URL...  fetches every feed, updates the cache, prints it
"""

from __future__ import annotations

import argparse
import calendar as pycal
from datetime import datetime, timedelta, timezone
import json
import os
import re
import secrets
import sys
import time
import urllib.error
import urllib.request
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

HTTP_TIMEOUT_S = 15
# The events kept: a year back and two ahead, as far as the view is usually
# browsed (the QML parser this replaces kept the same).
WINDOW_DAYS_BACK = 366
WINDOW_DAYS_AHEAD = 731

# Common Windows timezone names used by Exchange/Outlook ICS feeds.
WINDOWS_TZ_MAP = {
    "UTC": "UTC",
    "GMT Standard Time": "Europe/London",
    "Greenwich Standard Time": "Atlantic/Reykjavik",
    "W. Europe Standard Time": "Europe/Berlin",
    "Central Europe Standard Time": "Europe/Budapest",
    "Romance Standard Time": "Europe/Paris",
    "Central European Standard Time": "Europe/Warsaw",
    "E. Europe Standard Time": "Europe/Chisinau",
    "FLE Standard Time": "Europe/Kyiv",
    "GTB Standard Time": "Europe/Athens",
    "Russian Standard Time": "Europe/Moscow",
    "Eastern Standard Time": "America/New_York",
    "US Eastern Standard Time": "America/Indianapolis",
    "Central Standard Time": "America/Chicago",
    "Mountain Standard Time": "America/Denver",
    "US Mountain Standard Time": "America/Phoenix",
    "Pacific Standard Time": "America/Los_Angeles",
    "Alaskan Standard Time": "America/Anchorage",
    "Hawaiian Standard Time": "Pacific/Honolulu",
    "Canada Central Standard Time": "America/Regina",
    "Atlantic Standard Time": "America/Halifax",
    "E. South America Standard Time": "America/Sao_Paulo",
    "SA Eastern Standard Time": "America/Cayenne",
    "SA Pacific Standard Time": "America/Bogota",
    "Argentina Standard Time": "America/Buenos_Aires",
    "India Standard Time": "Asia/Kolkata",
    "China Standard Time": "Asia/Shanghai",
    "Tokyo Standard Time": "Asia/Tokyo",
    "Korea Standard Time": "Asia/Seoul",
    "Singapore Standard Time": "Asia/Singapore",
    "Taipei Standard Time": "Asia/Taipei",
    "AUS Eastern Standard Time": "Australia/Sydney",
    "AUS Central Standard Time": "Australia/Darwin",
    "W. Australia Standard Time": "Australia/Perth",
    "New Zealand Standard Time": "Pacific/Auckland",
    "Arabian Standard Time": "Asia/Dubai",
    "Israel Standard Time": "Asia/Jerusalem",
    "South Africa Standard Time": "Africa/Johannesburg",
}

MEETING_URL_RE = re.compile(
    r"https://(?:meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}"
    r"|[a-z0-9.-]*zoom\.us/j/\S+"
    r"|teams\.microsoft\.com/l/meetup-join/\S+"
    r"|teams\.live\.com/meet/\S+)",
    re.IGNORECASE,
)


def state_dir() -> str:
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    path = os.path.join(base, "guilhermerisu.island", "calendar")
    os.makedirs(path, mode=0o700, exist_ok=True)
    os.chmod(path, 0o700)
    return path


def cache_path() -> str:
    return os.path.join(state_dir(), "cache.json")


def read_json(path: str, default: dict) -> dict:
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        return data if isinstance(data, dict) else dict(default)
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return dict(default)


def atomic_write_json(path: str, data: dict) -> None:
    parent = os.path.dirname(path)
    os.makedirs(parent, mode=0o700, exist_ok=True)
    tmp = f"{path}.tmp.{os.getpid()}.{secrets.token_hex(4)}"
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(payload)
            fh.flush()
            os.fsync(fh.fileno())
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def load_cache() -> dict:
    return read_json(
        cache_path(),
        {"events": [], "fetchedAt": 0, "status": "missing", "errors": {}, "sources": {}},
    )


def save_cache(data: dict) -> None:
    atomic_write_json(cache_path(), data)


def public_cache_payload(cache: dict) -> dict:
    return {
        "events": cache.get("events", []),
        "fetchedAt": cache.get("fetchedAt", 0),
        "status": cache.get("status", "missing"),
        "errors": cache.get("errors", {}),
    }


def _http_request(
    url: str,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    data: bytes | None = None,
    timeout: int = HTTP_TIMEOUT_S,
) -> tuple[int, bytes]:
    req_headers = {"User-Agent": "IslandCalendar/1.0"}
    if headers:
        req_headers.update(headers)
    req = urllib.request.Request(url, data=data, headers=req_headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        body = exc.read()
        msg = f"HTTP {exc.code}"
        try:
            err_json = json.loads(body.decode("utf-8", errors="replace"))
            if isinstance(err_json, dict):
                detail = (
                    err_json.get("error_description")
                    or (
                        err_json.get("error", {}).get("message")
                        if isinstance(err_json.get("error"), dict)
                        else err_json.get("error")
                    )
                    or err_json.get("message")
                )
                if detail:
                    msg = f"HTTP {exc.code}: {detail}"
        except Exception:
            pass
        raise RuntimeError(msg) from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Network error: {exc.reason}") from exc



def normalize_hex_color(value: str) -> str:
    v = (value or "").strip()
    if re.fullmatch(r"#[0-9a-fA-F]{6}", v):
        return v.lower()
    return ""


def _local_midnight_ms(year: int, month: int, day: int) -> int:
    dt = datetime(year, month, day, 0, 0, 0).astimezone()
    return int(dt.timestamp() * 1000)


def resolve_tz(tzid: str):
    local_tz = datetime.now().astimezone().tzinfo
    if not tzid:
        return local_tz
    cleaned = tzid.strip().strip('"')
    if cleaned.upper() in ("UTC", "Z", "GMT", "ETC/UTC"):
        return timezone.utc
    mapped = WINDOWS_TZ_MAP.get(cleaned, cleaned)
    try:
        return ZoneInfo(mapped)
    except ZoneInfoNotFoundError:
        return local_tz


def _split_ics_line(line: str) -> tuple[str, dict[str, str], str] | None:
    in_quotes = False
    colon = -1
    for idx, ch in enumerate(line):
        if ch == '"':
            in_quotes = not in_quotes
        elif ch == ":" and not in_quotes:
            colon = idx
            break
    if colon < 0:
        return None
    head = line[:colon]
    value = line[colon + 1 :]

    parts: list[str] = []
    cur: list[str] = []
    in_quotes = False
    for ch in head:
        if ch == '"':
            in_quotes = not in_quotes
            cur.append(ch)
        elif ch == ";" and not in_quotes:
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    parts.append("".join(cur))

    name = parts[0].strip().upper()
    params: dict[str, str] = {}
    for p in parts[1:]:
        if "=" in p:
            k, v = p.split("=", 1)
            params[k.strip().upper()] = v.strip().strip('"')
    return name, params, value


def _ics_unescape(text: str) -> str:
    def repl(match: re.Match) -> str:
        c = match.group(1)
        return " " if c in ("n", "N") else c

    return re.sub(r"\\([\\;,nN])", repl, text).strip()


def _parse_ics_dt(prop: tuple[str, dict[str, str]]) -> dict | None:
    value, params = prop
    m = re.fullmatch(
        r"(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z?))?", value.strip()
    )
    if not m:
        return None
    y, mo, d = int(m.group(1)), int(m.group(2)), int(m.group(3))
    if m.group(4) is None:
        local_tz = datetime.now().astimezone().tzinfo
        dt = datetime(y, mo, d, 0, 0, 0, tzinfo=local_tz)
        return {
            "ms": int(dt.timestamp() * 1000),
            "allDay": True,
            "dt": dt,
            "tz": local_tz,
        }

    h, mi, s = int(m.group(4)), int(m.group(5)), int(m.group(6))
    is_utc = m.group(7) == "Z"
    tz = timezone.utc if is_utc else resolve_tz(params.get("TZID", ""))
    dt = datetime(y, mo, d, h, mi, s, tzinfo=tz)
    return {
        "ms": int(dt.timestamp() * 1000),
        "allDay": False,
        "dt": dt,
        "tz": tz,
    }


def _parse_duration_ms(text: str) -> int:
    m = re.fullmatch(
        r"[+]?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?",
        (text or "").strip(),
    )
    if not m:
        return 0
    w, d, h, mi, s = (int(m.group(i) or 0) for i in range(1, 6))
    return ((((w * 7 + d) * 24 + h) * 60 + mi) * 60 + s) * 1000


def _expand_rrule(rule_text: str, start_info: dict, to_ms: int) -> list[int]:
    rule: dict[str, str] = {}
    for part in rule_text.split(";"):
        if "=" in part:
            k, v = part.split("=", 1)
            rule[k.strip().upper()] = v.strip().upper()

    freq = rule.get("FREQ", "")
    first_ms = start_info["ms"]
    if freq not in ("DAILY", "WEEKLY", "MONTHLY", "YEARLY"):
        return [first_ms]

    every = max(1, int(rule.get("INTERVAL") or 1))
    count = int(rule.get("COUNT") or 0)
    until_ms = to_ms
    if "UNTIL" in rule:
        u = _parse_ics_dt((rule["UNTIL"], {}))
        if u:
            u_end = u["ms"] + (24 * 3600 * 1000 - 1 if u["allDay"] else 0)
            until_ms = min(to_ms, u_end)

    # Sunday=0..Saturday=6 in JS; in Python weekday() Monday=0..Sunday=6.
    codes_py = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}
    by_day: list[tuple[int, int]] = []
    if "BYDAY" in rule:
        for token in rule["BYDAY"].split(","):
            m = re.fullmatch(r"([+-]?\d+)?([A-Z]{2})", token.strip())
            if m and m.group(2) in codes_py:
                by_day.append((int(m.group(1) or 0), codes_py[m.group(2)]))

    by_month_day = (
        [int(x) for x in rule["BYMONTHDAY"].split(",") if x]
        if rule.get("BYMONTHDAY")
        else []
    )
    by_month = (
        [int(x) for x in rule["BYMONTH"].split(",") if x]
        if rule.get("BYMONTH")
        else []
    )
    set_pos = (
        [int(x) for x in rule["BYSETPOS"].split(",") if x]
        if rule.get("BYSETPOS")
        else []
    )

    s_dt: datetime = start_info["dt"]
    tz = start_info["tz"]

    def at(y: int, mo: int, d: int) -> datetime:
        return datetime(y, mo, d, s_dt.hour, s_dt.minute, s_dt.second, tzinfo=tz)

    def month_days(y: int, mo: int, fallback: int) -> list[datetime]:
        length = pycal.monthrange(y, mo)[1]
        days: list[int] = []
        if by_month_day:
            for d in by_month_day:
                day = length + d + 1 if d < 0 else d
                if 1 <= day <= length:
                    days.append(day)
            if by_day:
                wanted_wds = {wd for _, wd in by_day}
                days = [day for day in days if datetime(y, mo, day).weekday() in wanted_wds]
        elif by_day:
            for n, wd in by_day:
                matching = [day for day in range(1, length + 1) if datetime(y, mo, day).weekday() == wd]
                if n == 0:
                    days.extend(matching)
                else:
                    idx = n - 1 if n > 0 else len(matching) + n
                    if 0 <= idx < len(matching):
                        days.append(matching[idx])
        elif fallback <= length:
            days.append(fallback)
        return [at(y, mo, day) for day in days]

    starts: list[int] = []
    made = 0
    s_date = s_dt.date()
    monday = s_date - timedelta(days=s_date.weekday())

    for p in range(10000):
        period: list[datetime] = []
        if freq == "DAILY":
            d_obj = s_date + timedelta(days=p * every)
            cand = at(d_obj.year, d_obj.month, d_obj.day)
            period = [cand]
            if by_day:
                wanted_wds = {wd for _, wd in by_day}
                period = [dt for dt in period if dt.weekday() in wanted_wds]
            if by_month_day:
                filtered = []
                for dt in period:
                    length = pycal.monthrange(dt.year, dt.month)[1]
                    if any((length + md + 1 if md < 0 else md) == dt.day for md in by_month_day):
                        filtered.append(dt)
                period = filtered
        elif freq == "WEEKLY":
            wanted_wds = {wd for _, wd in by_day} if by_day else {s_date.weekday()}
            week_start = monday + timedelta(days=p * every * 7)
            for i in range(7):
                d_obj = week_start + timedelta(days=i)
                if d_obj.weekday() in wanted_wds:
                    period.append(at(d_obj.year, d_obj.month, d_obj.day))
        elif freq == "MONTHLY":
            total_months = (s_date.year * 12 + (s_date.month - 1)) + p * every
            y, mo0 = divmod(total_months, 12)
            period = month_days(y, mo0 + 1, s_date.day)
        else:  # YEARLY
            y = s_date.year + p * every
            months = by_month if by_month else [s_date.month]
            for mo in months:
                if 1 <= mo <= 12:
                    period.extend(month_days(y, mo, s_date.day))

        if by_month and freq != "YEARLY":
            period = [dt for dt in period if dt.month in by_month]

        period.sort()
        if set_pos and period:
            kept = period
            picked = []
            for n in set_pos:
                idx = n - 1 if n > 0 else len(kept) + n
                if 0 <= idx < len(kept):
                    picked.append(kept[idx])
            period = sorted(picked)

        period_start_ms = int(period[0].timestamp() * 1000) if period else 0
        for dt in period:
            ms = int(dt.timestamp() * 1000)
            if ms < first_ms:
                continue
            if ms > until_ms or (count and made >= count):
                return starts
            starts.append(ms)
            made += 1

        if period_start_ms > until_ms:
            break
        if freq == "DAILY":
            d_obj = s_date + timedelta(days=p * every)
            if int(at(d_obj.year, d_obj.month, d_obj.day).timestamp() * 1000) > until_ms:
                break
        elif freq == "WEEKLY":
            d_obj = monday + timedelta(days=p * every * 7)
            if int(at(d_obj.year, d_obj.month, d_obj.day).timestamp() * 1000) > until_ms:
                break
        elif freq == "MONTHLY":
            total_months = (s_date.year * 12 + (s_date.month - 1)) + p * every
            y, mo0 = divmod(total_months, 12)
            if int(datetime(y, mo0 + 1, 1, tzinfo=tz).timestamp() * 1000) > until_ms:
                break
        elif freq == "YEARLY":
            if int(datetime(s_date.year + p * every, 1, 1, tzinfo=tz).timestamp() * 1000) > until_ms:
                break

    return starts


def parse_ics(
    ics_text: str,
    now_ms: int | None = None,
    win_days_back: int = WINDOW_DAYS_BACK,
    win_days_ahead: int = WINDOW_DAYS_AHEAD,
) -> list[dict]:
    if now_ms is None:
        now_ms = int(time.time() * 1000)
    win_from = now_ms - win_days_back * 24 * 3600 * 1000
    win_to = now_ms + win_days_ahead * 24 * 3600 * 1000

    unfolded = re.sub(r"\r?\n[ \t]", "", ics_text)
    lines = re.split(r"\r?\n", unfolded)

    raw_events: list[dict] = []
    cur: dict | None = None
    sub_depth = 0
    cal_color = ""

    for line in lines:
        upper = line.strip().upper()
        if upper == "BEGIN:VEVENT":
            cur = {"EXDATE": []}
            sub_depth = 0
            continue
        if upper == "END:VEVENT":
            if cur is not None:
                raw_events.append(cur)
            cur = None
            sub_depth = 0
            continue
        if cur is None:
            parsed = _split_ics_line(line)
            if parsed and parsed[0] in ("X-WR-CALCOLOR", "COLOR") and not cal_color:
                cal_color = normalize_hex_color(parsed[2])
            continue
        if upper.startswith("BEGIN:"):
            sub_depth += 1
            continue
        if upper.startswith("END:"):
            if sub_depth > 0:
                sub_depth -= 1
            continue
        if sub_depth > 0:
            continue

        parsed = _split_ics_line(line)
        if not parsed:
            continue
        name, params, value = parsed
        if name == "EXDATE":
            for item in value.split(","):
                item = item.strip()
                if item:
                    cur["EXDATE"].append((item, params))
        elif name not in cur:
            cur[name] = (value, params)

    replaced: set[tuple[str, int]] = set()
    for ev in raw_events:
        if "RECURRENCE-ID" in ev and "UID" in ev:
            rec = _parse_ics_dt(ev["RECURRENCE-ID"])
            if rec:
                replaced.add((ev["UID"][0].strip(), rec["ms"]))

    events: list[dict] = []
    for ev in raw_events:
        if "DTSTART" not in ev:
            continue
        if "STATUS" in ev and ev["STATUS"][0].strip().upper() == "CANCELLED":
            continue
        start_info = _parse_ics_dt(ev["DTSTART"])
        if not start_info:
            continue

        end_info = _parse_ics_dt(ev["DTEND"]) if "DTEND" in ev else None
        if not end_info and "DURATION" in ev:
            dur = _parse_duration_ms(ev["DURATION"][0])
            end_ms = start_info["ms"] + dur
        elif end_info:
            end_ms = end_info["ms"]
        else:
            if start_info["allDay"]:
                s_dt = start_info["dt"]
                nxt = s_dt + timedelta(days=1)
                end_ms = _local_midnight_ms(nxt.year, nxt.month, nxt.day)
            else:
                end_ms = start_info["ms"]

        end_ms = max(end_ms, start_info["ms"])
        title = _ics_unescape(ev["SUMMARY"][0]) if "SUMMARY" in ev else ""
        title = title or "Untitled"
        location = _ics_unescape(ev["LOCATION"][0]) if "LOCATION" in ev else ""
        desc = _ics_unescape(ev["DESCRIPTION"][0]) if "DESCRIPTION" in ev else ""
        color = normalize_hex_color(ev["COLOR"][0]) if "COLOR" in ev else cal_color

        meeting_url = ""
        for prop_name in ("X-GOOGLE-CONFERENCE", "CONFERENCE", "URL"):
            if prop_name in ev:
                cand = ev[prop_name][0].strip()
                if cand.startswith(("https://", "http://")):
                    meeting_url = cand
                    break
        if not meeting_url:
            for text in (location, desc):
                m = MEETING_URL_RE.search(text)
                if m:
                    meeting_url = m.group(0)
                    break

        base_event = {
            "title": title,
            "allDay": start_info["allDay"],
            "color": color,
            "location": location,
            "meetingUrl": meeting_url,
            "source": "ics",
        }

        if "RRULE" not in ev:
            if end_ms >= win_from and start_info["ms"] <= win_to:
                events.append(
                    {
                        **base_event,
                        "start": start_info["ms"],
                        "end": end_ms,
                    }
                )
            continue

        skip: set[int] = set()
        for ex in ev["EXDATE"]:
            ex_dt = _parse_ics_dt(ex)
            if ex_dt:
                skip.add(ex_dt["ms"])
        uid = ev["UID"][0].strip() if "UID" in ev else ""
        duration = end_ms - start_info["ms"]

        for occ_start in _expand_rrule(ev["RRULE"][0], start_info, win_to):
            if occ_start in skip or (uid, occ_start) in replaced:
                continue
            occ_end = occ_start + duration
            if occ_end < win_from or occ_start > win_to:
                continue
            events.append(
                {
                    **base_event,
                    "start": occ_start,
                    "end": occ_end,
                }
            )

    return events


def fetch_ics_url(url: str, win_start_ms: int, win_end_ms: int) -> list[dict]:
    normalized = re.sub(r"^webcal://", "https://", url.strip(), flags=re.IGNORECASE)
    _, raw = _http_request(normalized, timeout=HTTP_TIMEOUT_S)
    text = raw.decode("utf-8", errors="replace")
    if "BEGIN:VCALENDAR" not in text:
        raise RuntimeError("Response is not a valid ICS calendar")
    now_ms = int((win_start_ms + WINDOW_DAYS_BACK * 24 * 3600 * 1000))
    return parse_ics(text, now_ms=now_ms)


def fetch_all(ics_urls: list[str]) -> dict:
    prev_cache = load_cache()
    prev_sources = prev_cache.get("sources") or {}

    now_ms = int(time.time() * 1000)
    win_start_ms = now_ms - WINDOW_DAYS_BACK * 24 * 3600 * 1000
    win_end_ms = now_ms + WINDOW_DAYS_AHEAD * 24 * 3600 * 1000

    normalized_ics: list[str] = []
    for u in ics_urls:
        u = re.sub(r"^webcal://", "https://", u.strip(), flags=re.IGNORECASE)
        if u and u not in normalized_ics:
            normalized_ics.append(u)

    if not normalized_ics:
        empty_cache = {
            "events": [],
            "fetchedAt": prev_cache.get("fetchedAt", 0),
            "status": "missing",
            "errors": {},
            "sources": {},
        }
        save_cache(empty_cache)
        return public_cache_payload(empty_cache)

    next_sources: dict[str, list[dict]] = {}
    errors: dict[str, str] = {}
    good_count = 0

    # A feed that can't be read keeps its last good reading.
    for url in normalized_ics:
        key = f"ics:{url}"
        try:
            next_sources[key] = fetch_ics_url(url, win_start_ms, win_end_ms)
            good_count += 1
        except Exception as exc:
            errors[key] = str(exc)
            if key in prev_sources:
                next_sources[key] = prev_sources[key]

    events: list[dict] = []
    for evs in next_sources.values():
        events.extend(evs)
    events.sort(key=lambda e: (e["start"], e["title"]))

    fetched_at = now_ms if good_count > 0 else prev_cache.get("fetchedAt", 0)
    status = "ready" if (good_count > 0 or bool(next_sources)) else "offline"

    cache = {
        "events": events,
        "fetchedAt": fetched_at,
        "status": status,
        "errors": errors,
        "sources": next_sources,
    }
    save_cache(cache)
    return public_cache_payload(cache)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="sync.py")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("cache")
    p_fetch = sub.add_parser("fetch")
    p_fetch.add_argument("--ics", nargs="*", default=[])
    args = parser.parse_args(argv)

    try:
        out = public_cache_payload(load_cache()) if args.cmd == "cache" else fetch_all(args.ics)
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
