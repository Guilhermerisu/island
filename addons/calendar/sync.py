#!/usr/bin/env python3
"""Calendar sync helper for the Island calendar addon.

Manages OAuth2 PKCE authentication and event synchronization for Google Calendar
and Outlook / Microsoft 365, as well as ICS feed parsing with TZID and RRULE
support. Uses Python 3 standard library only.
"""

from __future__ import annotations

import argparse
import base64
import calendar as pycal
from datetime import datetime, timedelta, timezone
import hashlib
import html
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import re
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_API_BASE = "https://www.googleapis.com/calendar/v3"
GOOGLE_USERINFO_URL = "https://openidconnect.googleapis.com/v1/userinfo"
GOOGLE_SCOPE = "https://www.googleapis.com/auth/calendar.readonly email"

OUTLOOK_AUTH_BASE = "https://login.microsoftonline.com"
OUTLOOK_GRAPH_BASE = "https://graph.microsoft.com/v1.0"
OUTLOOK_SCOPE = "offline_access Calendars.Read User.Read"

HTTP_TIMEOUT_S = 15
OAUTH_TIMEOUT_S = 180
WINDOW_DAYS_BACK = 60
WINDOW_DAYS_AHEAD = 180

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


def auth_path() -> str:
    return os.path.join(state_dir(), "auth.json")


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


def load_auth() -> dict:
    return read_json(auth_path(), {})


def save_auth(data: dict) -> None:
    atomic_write_json(auth_path(), data)


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


def build_status(auth: dict, cache: dict | None = None) -> dict:
    g = auth.get("google") or {}
    o = auth.get("outlook") or {}

    def format_calendars(entry: dict) -> list[dict]:
        selected = set(entry.get("selectedIds") or [])
        result = []
        for cal in entry.get("calendars") or []:
            cid = cal.get("id", "")
            result.append(
                {
                    "id": cid,
                    "name": cal.get("name") or cid,
                    "color": cal.get("color") or "",
                    "selected": cid in selected,
                }
            )
        return result

    g_connected = bool(g.get("refreshToken") or g.get("accessToken"))
    o_connected = bool(o.get("refreshToken") or o.get("accessToken"))
    if cache is None:
        cache = load_cache()

    return {
        "google": {
            "connected": g_connected,
            "email": g.get("email", "") if g_connected else "",
            "clientId": g.get("clientId", ""),
            "hasSecret": bool(g.get("clientSecret")),
            "calendars": format_calendars(g) if g_connected else [],
            "error": g.get("error", ""),
        },
        "outlook": {
            "connected": o_connected,
            "email": o.get("email", "") if o_connected else "",
            "clientId": o.get("clientId", ""),
            "tenant": o.get("tenant") or "common",
            "calendars": format_calendars(o) if o_connected else [],
            "error": o.get("error", ""),
        },
        "fetchedAt": cache.get("fetchedAt", 0),
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


def http_json(
    url: str,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    form: dict[str, str] | None = None,
    timeout: int = HTTP_TIMEOUT_S,
) -> dict:
    req_headers = dict(headers or {})
    body = None
    if form is not None:
        body = urllib.parse.urlencode(form).encode("utf-8")
        req_headers.setdefault("Content-Type", "application/x-www-form-urlencoded")
    _, raw = _http_request(url, method=method, headers=req_headers, data=body, timeout=timeout)
    return json.loads(raw.decode("utf-8"))


def pkce_pair() -> tuple[str, str]:
    verifier = secrets.token_urlsafe(64)
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    challenge = base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")
    return verifier, challenge


def run_oauth_callback_server(
    build_auth_url, redirect_host: str
) -> tuple[str, str]:
    """Starts a local HTTP callback server, opens the browser, and waits for code."""
    result: dict[str, str] = {}
    expected_state = secrets.token_urlsafe(24)

    class CallbackHandler(BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            return

        def do_GET(self):
            parsed = urllib.parse.urlparse(self.path)
            if parsed.path != "/callback":
                self.send_response(204)
                self.end_headers()
                return
            params = urllib.parse.parse_qs(parsed.query)
            err = (params.get("error") or [""])[0]
            err_desc = (params.get("error_description") or [""])[0]
            state = (params.get("state") or [""])[0]
            code = (params.get("code") or [""])[0]

            if err:
                result["error"] = err_desc or err
                self._send_html(
                    400,
                    "Authorization failed",
                    f"Could not connect to Island: {html.escape(result['error'])}",
                )
            elif not state or not secrets.compare_digest(state, expected_state):
                result["error"] = "OAuth state mismatch"
                self._send_html(400, "Authorization failed", "Invalid OAuth state.")
            elif not code:
                result["error"] = "Missing authorization code"
                self._send_html(400, "Authorization failed", "Missing authorization code.")
            else:
                result["code"] = code
                self._send_html(
                    200,
                    "Connected to Island",
                    "Connected to Island — you can close this tab.",
                )

        def _send_html(self, status: int, title: str, message: str) -> None:
            page = (
                "<!doctype html><html><head><meta charset='utf-8'>"
                f"<title>{title}</title>"
                "<style>body{font-family:system-ui,sans-serif;display:flex;"
                "align-items:center;justify-content:center;min-height:100vh;"
                "margin:0;background:#111;color:#f5f5f7}"
                ".card{padding:28px 36px;border-radius:16px;background:#1c1c1e;"
                "border:1px solid rgba(255,255,255,.12);text-align:center}"
                "h1{font-size:18px;margin:0 0 8px}p{margin:0;color:#a1a1a6;font-size:14px}"
                "</style></head><body><div class='card'>"
                f"<h1>{title}</h1><p>{message}</p></div></body></html>"
            ).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(page)))
            self.end_headers()
            self.wfile.write(page)

    server = HTTPServer(("127.0.0.1", 0), CallbackHandler)
    server.timeout = 1.0
    port = server.server_address[1]
    redirect_uri = f"http://{redirect_host}:{port}/callback"
    auth_url = build_auth_url(redirect_uri, expected_state)

    try:
        subprocess.Popen(
            ["xdg-open", auth_url],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError as exc:
        server.server_close()
        raise RuntimeError(f"Could not open browser: {exc}") from exc

    deadline = time.monotonic() + OAUTH_TIMEOUT_S
    try:
        while "code" not in result and "error" not in result:
            if time.monotonic() >= deadline:
                raise RuntimeError("Timed out waiting for browser authorization (180s)")
            server.handle_request()
    finally:
        server.server_close()

    if "error" in result:
        raise RuntimeError(result["error"])
    return result["code"], redirect_uri


def auth_google(client_id: str, client_secret: str = "") -> dict:
    client_id = client_id.strip()
    client_secret = client_secret.strip()
    if not client_id:
        raise RuntimeError("Google Client ID is required")

    verifier, challenge = pkce_pair()

    def build_url(redirect_uri: str, state: str) -> str:
        qs = urllib.parse.urlencode(
            {
                "client_id": client_id,
                "redirect_uri": redirect_uri,
                "response_type": "code",
                "scope": GOOGLE_SCOPE,
                "access_type": "offline",
                "prompt": "consent",
                "code_challenge": challenge,
                "code_challenge_method": "S256",
                "state": state,
            }
        )
        return f"{GOOGLE_AUTH_URL}?{qs}"

    code, redirect_uri = run_oauth_callback_server(build_url, "127.0.0.1")

    token_form = {
        "client_id": client_id,
        "code": code,
        "code_verifier": verifier,
        "redirect_uri": redirect_uri,
        "grant_type": "authorization_code",
    }
    if client_secret:
        token_form["client_secret"] = client_secret

    tokens = http_json(GOOGLE_TOKEN_URL, method="POST", form=token_form)
    access_token = tokens.get("access_token", "")
    if not access_token:
        raise RuntimeError("Google did not return an access token")
    refresh_token = tokens.get("refresh_token", "")
    expires_at = time.time() + float(tokens.get("expires_in", 3600))

    headers = {"Authorization": f"Bearer {access_token}"}
    cal_data = http_json(f"{GOOGLE_API_BASE}/users/me/calendarList", headers=headers)
    calendars, default_selected = _parse_google_calendars(cal_data)

    email = ""
    try:
        userinfo = http_json(GOOGLE_USERINFO_URL, headers=headers)
        email = userinfo.get("email", "")
    except Exception:
        pass
    if not email:
        for item in cal_data.get("items") or []:
            if item.get("primary") and "@" in (item.get("id") or ""):
                email = item["id"]
                break

    auth = load_auth()
    prev_selected = (auth.get("google") or {}).get("selectedIds")
    valid_ids = {c["id"] for c in calendars}
    if prev_selected:
        selected_ids = [cid for cid in prev_selected if cid in valid_ids]
    else:
        selected_ids = default_selected

    auth["google"] = {
        "clientId": client_id,
        "clientSecret": client_secret,
        "accessToken": access_token,
        "refreshToken": refresh_token or (auth.get("google") or {}).get("refreshToken", ""),
        "expiresAt": expires_at,
        "email": email,
        "calendars": calendars,
        "selectedIds": selected_ids,
        "error": "",
    }
    save_auth(auth)
    return build_status(auth)


def _parse_google_calendars(cal_data: dict) -> tuple[list[dict], list[str]]:
    calendars = []
    default_selected = []
    for item in cal_data.get("items") or []:
        cid = item.get("id") or ""
        if not cid:
            continue
        name = item.get("summaryOverride") or item.get("summary") or cid
        color = normalize_hex_color(item.get("backgroundColor") or "")
        calendars.append({"id": cid, "name": name, "color": color})
        if item.get("selected", True):
            default_selected.append(cid)
    if not default_selected and calendars:
        default_selected = [calendars[0]["id"]]
    return calendars, default_selected


def auth_outlook(client_id: str, tenant: str = "common") -> dict:
    client_id = client_id.strip()
    tenant = (tenant or "common").strip() or "common"
    if not client_id:
        raise RuntimeError("Outlook Client ID is required")

    verifier, challenge = pkce_pair()
    safe_tenant = urllib.parse.quote(tenant, safe="")

    def build_url(redirect_uri: str, state: str) -> str:
        qs = urllib.parse.urlencode(
            {
                "client_id": client_id,
                "response_type": "code",
                "redirect_uri": redirect_uri,
                "response_mode": "query",
                "scope": OUTLOOK_SCOPE,
                "code_challenge": challenge,
                "code_challenge_method": "S256",
                "state": state,
            }
        )
        return f"{OUTLOOK_AUTH_BASE}/{safe_tenant}/oauth2/v2.0/authorize?{qs}"

    code, redirect_uri = run_oauth_callback_server(build_url, "localhost")

    token_url = f"{OUTLOOK_AUTH_BASE}/{safe_tenant}/oauth2/v2.0/token"
    tokens = http_json(
        token_url,
        method="POST",
        form={
            "client_id": client_id,
            "scope": OUTLOOK_SCOPE,
            "code": code,
            "redirect_uri": redirect_uri,
            "grant_type": "authorization_code",
            "code_verifier": verifier,
        },
    )
    access_token = tokens.get("access_token", "")
    if not access_token:
        raise RuntimeError("Microsoft did not return an access token")
    refresh_token = tokens.get("refresh_token", "")
    expires_at = time.time() + float(tokens.get("expires_in", 3600))

    headers = {"Authorization": f"Bearer {access_token}"}
    me = http_json(f"{OUTLOOK_GRAPH_BASE}/me", headers=headers)
    email = me.get("mail") or me.get("userPrincipalName") or ""

    cal_data = http_json(f"{OUTLOOK_GRAPH_BASE}/me/calendars", headers=headers)
    calendars, default_selected = _parse_outlook_calendars(cal_data)

    auth = load_auth()
    prev_selected = (auth.get("outlook") or {}).get("selectedIds")
    valid_ids = {c["id"] for c in calendars}
    if prev_selected:
        selected_ids = [cid for cid in prev_selected if cid in valid_ids]
    else:
        selected_ids = default_selected

    auth["outlook"] = {
        "clientId": client_id,
        "tenant": tenant,
        "accessToken": access_token,
        "refreshToken": refresh_token or (auth.get("outlook") or {}).get("refreshToken", ""),
        "expiresAt": expires_at,
        "email": email,
        "calendars": calendars,
        "selectedIds": selected_ids,
        "error": "",
    }
    save_auth(auth)
    return build_status(auth)


def _parse_outlook_calendars(cal_data: dict) -> tuple[list[dict], list[str]]:
    calendars = []
    default_selected = []
    for item in cal_data.get("value") or []:
        cid = item.get("id") or ""
        if not cid:
            continue
        name = item.get("name") or cid
        color = normalize_hex_color(item.get("hexColor") or "")
        calendars.append({"id": cid, "name": name, "color": color})
        if item.get("isDefaultCalendar"):
            default_selected.append(cid)
    if not default_selected:
        default_selected = [c["id"] for c in calendars]
    return calendars, default_selected


def disconnect_provider(provider: str) -> dict:
    auth = load_auth()
    auth.pop(provider, None)
    save_auth(auth)

    cache = load_cache()
    sources = dict(cache.get("sources") or {})
    sources.pop(provider, None)
    errors = dict(cache.get("errors") or {})
    errors.pop(provider, None)

    events = []
    for src_events in sources.values():
        events.extend(src_events)
    events.sort(key=lambda e: (e["start"], e["title"]))

    has_sources = bool(auth.get("google") or auth.get("outlook") or sources)
    cache["sources"] = sources
    cache["errors"] = errors
    cache["events"] = events
    if not has_sources:
        cache["status"] = "missing"
    elif events:
        cache["status"] = "ready"
    save_cache(cache)

    return build_status(auth, cache)


def select_calendars(provider: str, ids_csv: str) -> dict:
    auth = load_auth()
    entry = auth.get(provider)
    if not entry:
        raise RuntimeError(f"{provider} is not connected")
    known = {c["id"] for c in entry.get("calendars") or []}
    wanted = [cid for cid in ids_csv.split(",") if cid]
    if known:
        wanted = [cid for cid in wanted if cid in known]
    entry["selectedIds"] = wanted
    auth[provider] = entry
    save_auth(auth)
    return build_status(auth)


def _ensure_google_token(auth: dict) -> str:
    g = auth.get("google") or {}
    access_token = g.get("accessToken") or ""
    expires_at = float(g.get("expiresAt") or 0)
    if access_token and time.time() < expires_at - 60:
        return access_token

    refresh_token = g.get("refreshToken") or ""
    client_id = g.get("clientId") or ""
    if not refresh_token or not client_id:
        raise RuntimeError("Google session expired; reconnect in Settings")

    form = {
        "client_id": client_id,
        "refresh_token": refresh_token,
        "grant_type": "refresh_token",
    }
    if g.get("clientSecret"):
        form["client_secret"] = g["clientSecret"]

    tokens = http_json(GOOGLE_TOKEN_URL, method="POST", form=form)
    new_access = tokens.get("access_token") or ""
    if not new_access:
        raise RuntimeError("Failed to refresh Google access token")

    g["accessToken"] = new_access
    if tokens.get("refresh_token"):
        g["refreshToken"] = tokens["refresh_token"]
    g["expiresAt"] = time.time() + float(tokens.get("expires_in", 3600))
    g["error"] = ""
    auth["google"] = g
    save_auth(auth)
    return new_access


def _ensure_outlook_token(auth: dict) -> str:
    o = auth.get("outlook") or {}
    access_token = o.get("accessToken") or ""
    expires_at = float(o.get("expiresAt") or 0)
    if access_token and time.time() < expires_at - 60:
        return access_token

    refresh_token = o.get("refreshToken") or ""
    client_id = o.get("clientId") or ""
    tenant = urllib.parse.quote((o.get("tenant") or "common").strip() or "common", safe="")
    if not refresh_token or not client_id:
        raise RuntimeError("Outlook session expired; reconnect in Settings")

    tokens = http_json(
        f"{OUTLOOK_AUTH_BASE}/{tenant}/oauth2/v2.0/token",
        method="POST",
        form={
            "client_id": client_id,
            "scope": OUTLOOK_SCOPE,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        },
    )
    new_access = tokens.get("access_token") or ""
    if not new_access:
        raise RuntimeError("Failed to refresh Outlook access token")

    o["accessToken"] = new_access
    if tokens.get("refresh_token"):
        o["refreshToken"] = tokens["refresh_token"]
    o["expiresAt"] = time.time() + float(tokens.get("expires_in", 3600))
    o["error"] = ""
    auth["outlook"] = o
    save_auth(auth)
    return new_access


def normalize_hex_color(value: str) -> str:
    v = (value or "").strip()
    if re.fullmatch(r"#[0-9a-fA-F]{6}", v):
        return v.lower()
    return ""


def _local_midnight_ms(year: int, month: int, day: int) -> int:
    dt = datetime(year, month, day, 0, 0, 0).astimezone()
    return int(dt.timestamp() * 1000)


def _iso_to_ms(iso_str: str, assume_utc: bool = False) -> int:
    s = iso_str.strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    dt = datetime.fromisoformat(s)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc if assume_utc else datetime.now().astimezone().tzinfo)
    return int(dt.timestamp() * 1000)


def normalize_google_event(item: dict, cal_color: str = "") -> dict | None:
    if (item.get("status") or "").lower() == "cancelled":
        return None
    start_obj = item.get("start") or {}
    end_obj = item.get("end") or {}

    if "date" in start_obj:
        all_day = True
        y, m, d = (int(p) for p in start_obj["date"][:10].split("-"))
        start_ms = _local_midnight_ms(y, m, d)
        if "date" in end_obj:
            ey, em, ed = (int(p) for p in end_obj["date"][:10].split("-"))
            end_ms = _local_midnight_ms(ey, em, ed)
        else:
            end_ms = _local_midnight_ms(*(datetime(y, m, d) + timedelta(days=1)).timetuple()[:3])
    elif "dateTime" in start_obj:
        all_day = False
        start_ms = _iso_to_ms(start_obj["dateTime"])
        end_ms = _iso_to_ms(end_obj["dateTime"]) if "dateTime" in end_obj else start_ms
    else:
        return None

    meeting_url = (item.get("hangoutLink") or "").strip()
    if not meeting_url:
        for ep in (item.get("conferenceData") or {}).get("entryPoints") or []:
            if ep.get("entryPointType") == "video" and ep.get("uri"):
                meeting_url = str(ep["uri"]).strip()
                break
    if not meeting_url.startswith(("https://", "http://")):
        meeting_url = ""

    return {
        "title": (item.get("summary") or "").strip() or "Untitled",
        "start": start_ms,
        "end": max(end_ms, start_ms),
        "allDay": all_day,
        "color": normalize_hex_color(cal_color),
        "location": (item.get("location") or "").strip(),
        "meetingUrl": meeting_url,
        "source": "google",
    }


def fetch_google_events(auth: dict, win_start_ms: int, win_end_ms: int) -> list[dict]:
    token = _ensure_google_token(auth)
    g = auth["google"]
    headers = {"Authorization": f"Bearer {token}"}
    cal_colors = {c["id"]: c.get("color", "") for c in g.get("calendars") or []}
    selected = g.get("selectedIds") or []

    time_min = datetime.fromtimestamp(win_start_ms / 1000, tz=timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )
    time_max = datetime.fromtimestamp(win_end_ms / 1000, tz=timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )

    events: list[dict] = []
    for cal_id in selected:
        cal_color = cal_colors.get(cal_id, "")
        page_token = ""
        while True:
            params = {
                "singleEvents": "true",
                "orderBy": "startTime",
                "timeMin": time_min,
                "timeMax": time_max,
                "maxResults": "250",
            }
            if page_token:
                params["pageToken"] = page_token
            qs = urllib.parse.urlencode(params)
            quoted_id = urllib.parse.quote(cal_id, safe="")
            data = http_json(
                f"{GOOGLE_API_BASE}/calendars/{quoted_id}/events?{qs}",
                headers=headers,
            )
            for item in data.get("items") or []:
                ev = normalize_google_event(item, cal_color)
                if ev:
                    events.append(ev)
            page_token = data.get("nextPageToken") or ""
            if not page_token:
                break
    return events


def normalize_outlook_event(item: dict, cal_color: str = "") -> dict | None:
    if item.get("isCancelled"):
        return None
    start_obj = item.get("start") or {}
    end_obj = item.get("end") or {}
    start_dt = start_obj.get("dateTime")
    if not start_dt:
        return None
    end_dt = end_obj.get("dateTime") or start_dt
    all_day = bool(item.get("isAllDay"))

    if all_day:
        y, m, d = (int(p) for p in start_dt[:10].split("-"))
        start_ms = _local_midnight_ms(y, m, d)
        ey, em, ed = (int(p) for p in end_dt[:10].split("-"))
        end_ms = _local_midnight_ms(ey, em, ed)
        if end_ms <= start_ms:
            nxt = datetime(y, m, d) + timedelta(days=1)
            end_ms = _local_midnight_ms(nxt.year, nxt.month, nxt.day)
    else:
        start_ms = _iso_to_ms(start_dt, assume_utc=True)
        end_ms = _iso_to_ms(end_dt, assume_utc=True)

    meeting_url = (
        (item.get("onlineMeeting") or {}).get("joinUrl")
        or item.get("onlineMeetingUrl")
        or ""
    ).strip()
    if not meeting_url.startswith(("https://", "http://")):
        meeting_url = ""

    return {
        "title": (item.get("subject") or "").strip() or "Untitled",
        "start": start_ms,
        "end": max(end_ms, start_ms),
        "allDay": all_day,
        "color": normalize_hex_color(cal_color),
        "location": ((item.get("location") or {}).get("displayName") or "").strip(),
        "meetingUrl": meeting_url,
        "source": "outlook",
    }


def fetch_outlook_events(auth: dict, win_start_ms: int, win_end_ms: int) -> list[dict]:
    token = _ensure_outlook_token(auth)
    o = auth["outlook"]
    headers = {
        "Authorization": f"Bearer {token}",
        "Prefer": 'outlook.timezone="UTC"',
    }
    cal_colors = {c["id"]: c.get("color", "") for c in o.get("calendars") or []}
    selected = o.get("selectedIds") or []

    start_iso = datetime.fromtimestamp(win_start_ms / 1000, tz=timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )
    end_iso = datetime.fromtimestamp(win_end_ms / 1000, tz=timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )

    events: list[dict] = []
    for cal_id in selected:
        cal_color = cal_colors.get(cal_id, "")
        quoted_id = urllib.parse.quote(cal_id, safe="")
        qs = urllib.parse.urlencode(
            {
                "startDateTime": start_iso,
                "endDateTime": end_iso,
                "$top": "250",
            }
        )
        next_url: str | None = (
            f"{OUTLOOK_GRAPH_BASE}/me/calendars/{quoted_id}/calendarView?{qs}"
        )
        while next_url:
            data = http_json(next_url, headers=headers)
            for item in data.get("value") or []:
                ev = normalize_outlook_event(item, cal_color)
                if ev:
                    events.append(ev)
            next_url = data.get("@odata.nextLink")
    return events


# ---------- ICS parsing with TZID & RRULE ----------


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
    auth = load_auth()
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

    has_google = bool((auth.get("google") or {}).get("refreshToken") or (auth.get("google") or {}).get("accessToken"))
    has_outlook = bool((auth.get("outlook") or {}).get("refreshToken") or (auth.get("outlook") or {}).get("accessToken"))

    if not has_google and not has_outlook and not normalized_ics:
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

    if has_google:
        try:
            next_sources["google"] = fetch_google_events(auth, win_start_ms, win_end_ms)
            good_count += 1
        except Exception as exc:
            errors["google"] = str(exc)
            if "google" in prev_sources:
                next_sources["google"] = prev_sources["google"]

    if has_outlook:
        try:
            next_sources["outlook"] = fetch_outlook_events(auth, win_start_ms, win_end_ms)
            good_count += 1
        except Exception as exc:
            errors["outlook"] = str(exc)
            if "outlook" in prev_sources:
                next_sources["outlook"] = prev_sources["outlook"]

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

    sub.add_parser("status")
    sub.add_parser("cache")

    p_auth = sub.add_parser("auth")
    p_auth.add_argument("provider", choices=["google", "outlook"])
    p_auth.add_argument("--client-id", required=True)
    p_auth.add_argument("--client-secret", default="")
    p_auth.add_argument("--tenant", default="common")

    p_disc = sub.add_parser("disconnect")
    p_disc.add_argument("provider", choices=["google", "outlook"])

    p_sel = sub.add_parser("select")
    p_sel.add_argument("provider", choices=["google", "outlook"])
    p_sel.add_argument("--ids", default="")

    p_fetch = sub.add_parser("fetch")
    p_fetch.add_argument("--ics", nargs="*", default=[])

    args = parser.parse_args(argv)

    try:
        if args.cmd == "status":
            out = build_status(load_auth())
        elif args.cmd == "cache":
            out = public_cache_payload(load_cache())
        elif args.cmd == "auth":
            if args.provider == "google":
                out = auth_google(args.client_id, args.client_secret)
            else:
                out = auth_outlook(args.client_id, args.tenant)
        elif args.cmd == "disconnect":
            out = disconnect_provider(args.provider)
        elif args.cmd == "select":
            out = select_calendars(args.provider, args.ids)
        elif args.cmd == "fetch":
            out = fetch_all(args.ics)
        else:
            raise RuntimeError(f"Unknown command: {args.cmd}")
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
