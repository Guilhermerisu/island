#!/usr/bin/env python3
"""Merge Antigravity desktop/IDE transcripts into Omarchy's agy.json record.

omarchy-agent-usage-agy only scans AGY_DIR (default ~/.gemini/antigravity-cli),
missing conversations stored by the Antigravity app (~/.gemini/antigravity) and
Antigravity IDE (~/.gemini/antigravity-ide). This scans those extra roots using
the same transcript token parser and merges their daily and per-model token
totals into ~/.local/state/omarchy/agents/usage/agy.json without double-counting.
"""

import json
import math
import os
import re
import tempfile
from datetime import datetime, timezone
from pathlib import Path

HOME = Path.home()
STATE = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local/state")
RECORD = STATE / "omarchy/agents/usage/agy.json"

MODEL_SELECTION = re.compile(r"Model Selection` (?:from .+? )?to (.+?)\.(?:\s|$|<)")


def number(value):
  if isinstance(value, bool) or value is None:
    return 0
  try:
    n = float(value)
    if not math.isfinite(n) or n < 0 or n > 1e13:
      return 0
    return int(n)
  except (TypeError, ValueError):
    return 0


def parse_time(value):
  if value is None or value == "" or isinstance(value, bool):
    return None
  try:
    if isinstance(value, (int, float)) or str(value).isdigit():
      stamp = float(value)
      if not stamp > 0:
        return None
      parsed = datetime.fromtimestamp(stamp / 1000 if stamp > 1e12 else stamp, timezone.utc)
    else:
      parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
      if not parsed.tzinfo:
        parsed = parsed.replace(tzinfo=timezone.utc)
  except (ValueError, OverflowError, OSError):
    return None
  return None if parsed == datetime.min.replace(tzinfo=timezone.utc) else parsed


def local_day(value):
  parsed = parse_time(value)
  if parsed is None:
    return ""
  try:
    day = parsed.astimezone().date()
  except (ValueError, OverflowError, OSError):
    return ""
  return day.isoformat() if 2000 <= day.year <= 2100 else ""


def model_key(name):
  key = re.sub(r"[\s_]+", "-", re.sub(r"[()]", " ", str(name)).strip().lower())
  return re.sub(r"-+", "-", key).strip("-")


def step_model(step):
  for field in ("model", "model_name", "model_id"):
    value = step.get(field)
    if isinstance(value, str) and model_key(value):
      return model_key(value)
  return ""


def selected_model(step):
  content = step.get("content")
  if not isinstance(content, str) or "Model Selection" not in content:
    return ""
  match = MODEL_SELECTION.search(content)
  return model_key(match.group(1)) if match else ""


def step_tokens(step):
  usage = step.get("usage")
  for source in ([usage] if isinstance(usage, dict) else []) + [step]:
    if "prompt_token_count" in source or "candidates_token_count" in source:
      prompt = number(source.get("prompt_token_count"))
      cached = min(prompt, number(source.get("cached_content_token_count")))
      output = number(source.get("candidates_token_count")) + number(source.get("thoughts_token_count"))
      return prompt - cached, output, cached, 0
    if any(k in source for k in ("input_tokens", "output_tokens", "cache_read_tokens", "cache_write_tokens")):
      return (
        number(source.get("input_tokens")),
        number(source.get("output_tokens")),
        number(source.get("cache_read_tokens")),
        number(source.get("cache_write_tokens")),
      )
  return None


def extra_roots():
  primary = Path(os.environ.get("AGY_DIR") or (HOME / ".gemini/antigravity-cli"))
  seen = set()
  try:
    seen.add(primary.resolve())
  except OSError:
    seen.add(primary)
  roots = []
  for candidate in (HOME / ".gemini/antigravity", HOME / ".gemini/antigravity-ide"):
    if not candidate.is_dir():
      continue
    try:
      resolved = candidate.resolve()
    except OSError:
      resolved = candidate
    if resolved not in seen:
      seen.add(resolved)
      roots.append(resolved)
  return roots


def scan_root(root):
  by_day = {}
  by_model = {}
  by_day_model = {}
  for transcript in (root / "brain").glob("*/.system_generated/logs/transcript.jsonl"):
    try:
      lines = transcript.read_text(encoding="utf-8", errors="ignore").splitlines()
    except OSError:
      continue
    current = ""
    for line in lines:
      try:
        step = json.loads(line)
      except ValueError:
        continue
      if not isinstance(step, dict):
        continue
      current = step_model(step) or selected_model(step) or current
      tokens = step_tokens(step)
      if not tokens or not any(tokens):
        continue
      inp, out, cache_read, cache_write = tokens
      total = inp + out + cache_read + cache_write
      model = current or "unknown"
      bucket = by_model.setdefault(model, {"inputTokens": 0, "outputTokens": 0, "cacheReadInputTokens": 0, "cacheCreationInputTokens": 0})
      bucket["inputTokens"] += inp
      bucket["outputTokens"] += out
      bucket["cacheReadInputTokens"] += cache_read
      bucket["cacheCreationInputTokens"] += cache_write
      day = local_day(step.get("created_at") or step.get("timestamp"))
      if day:
        by_day[day] = by_day.get(day, 0) + total
        dm = by_day_model.setdefault(day, {})
        dm[model] = dm.get(model, 0) + total
  return by_day, by_model, by_day_model


def main():
  try:
    record = json.loads(RECORD.read_text())
  except Exception:
    return
  if not isinstance(record, dict) or record.get("_islandMergedRoots"):
    return

  roots = extra_roots()
  if not roots:
    return

  added_any = False
  today = datetime.now().astimezone().date().isoformat()
  recent_map = {d["date"]: d for d in (record.get("recentDays") or []) if isinstance(d, dict) and d.get("date")}
  model_usage = record.setdefault("modelUsage", {})
  today_by_model = record.setdefault("todayTokensByModel", {})
  active_dates = set(record.get("activeDates") or [])

  for root in roots:
    by_day, by_model, by_day_model = scan_root(root)
    if not by_model and not by_day:
      continue
    added_any = True
    for day, total in by_day.items():
      if total > 0:
        active_dates.add(day)
      if day in recent_map:
        recent_map[day]["messageCount"] = number(recent_map[day].get("messageCount")) + total
    if today in by_day:
      record["todayTotalTokens"] = number(record.get("todayTotalTokens")) + by_day[today]
    for model, total in (by_day_model.get(today) or {}).items():
      today_by_model[model] = number(today_by_model.get(model)) + total
    for model, counts in by_model.items():
      dst = model_usage.setdefault(model, {"inputTokens": 0, "outputTokens": 0, "cacheReadInputTokens": 0, "cacheCreationInputTokens": 0})
      for k in ("inputTokens", "outputTokens", "cacheReadInputTokens", "cacheCreationInputTokens"):
        dst[k] = number(dst.get(k)) + counts[k]

  if not added_any:
    return

  record["hasLocalStats"] = True
  record["ready"] = True
  record["activeDates"] = sorted(active_dates)
  record["activeDays"] = len(active_dates)
  record["_islandMergedRoots"] = [str(r) for r in roots]

  fd, tmp = tempfile.mkstemp(dir=RECORD.parent, prefix=".agy.")
  try:
    with os.fdopen(fd, "w") as out:
      json.dump(record, out)
    os.chmod(tmp, 0o600)
    os.replace(tmp, RECORD)
  except Exception:
    try:
      os.unlink(tmp)
    except OSError:
      pass


if __name__ == "__main__":
  main()
