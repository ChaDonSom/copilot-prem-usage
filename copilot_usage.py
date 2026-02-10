from __future__ import annotations

import dataclasses
import datetime as dt
import json
import math
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Callable, Dict, Iterable, Optional


class UsageError(RuntimeError):
    pass


@dataclasses.dataclass
class UsageSnapshot:
    login: str
    plan: str
    limit: int
    remaining: int
    percent_remaining: float
    unlimited: bool
    reset_date: dt.date

    @property
    def used(self) -> int:
        return max(self.limit - self.remaining, 0)


@dataclasses.dataclass
class UsageComputation:
    usage_pct: float
    used: int
    used_today: int
    days_until_reset: float
    hours_until_reset: float
    daily_budget: int
    hourly_budgets: Dict[str, float]
    warning: Optional[str]
    status: str


def parse_usage_payload(payload: Dict) -> UsageSnapshot:
    try:
        premium = payload["quota_snapshots"]["premium_interactions"]
    except KeyError as exc:
        raise ValueError("Invalid payload: missing premium_interactions") from exc

    limit = int(premium.get("entitlement") or 0)
    remaining = int(premium.get("remaining") or 0)
    percent_remaining = float(premium.get("percent_remaining") or 0)
    unlimited = bool(premium.get("unlimited", False))
    reset_date_raw = payload.get("quota_reset_date")

    if reset_date_raw:
        reset_date = dt.date.fromisoformat(str(reset_date_raw))
    else:
        reset_date = dt.date.today()

    login = payload.get("login") or "unknown"
    plan = payload.get("copilot_plan") or "unknown"

    # Unlimited plans do not need quota math
    if unlimited:
        limit = 0
        remaining = 0
        percent_remaining = percent_remaining or 100

    return UsageSnapshot(
        login=login,
        plan=plan,
        limit=limit,
        remaining=remaining,
        percent_remaining=percent_remaining,
        unlimited=unlimited,
        reset_date=reset_date,
    )


def calculate_days_until_reset(reset_date: dt.date, now: Optional[dt.datetime] = None) -> float:
    now = now or dt.datetime.now(dt.timezone.utc)
    if now.tzinfo is None:
        now = now.replace(tzinfo=dt.timezone.utc)

    reset_dt = dt.datetime.combine(reset_date, dt.time(), tzinfo=dt.timezone.utc)
    delta = reset_dt - now
    return max(delta.total_seconds() / 86400, 0.0)


def calculate_daily_budget(remaining: int, days_until_reset: float) -> int:
    whole_days = int(math.floor(days_until_reset))
    if whole_days <= 0:
        return 0
    return max(int(math.floor(remaining / whole_days)), 0)


def compute_used_today(cache_path: Path, current_date: dt.date, remaining: int) -> int:
    used_today = 0

    if cache_path.exists():
        try:
            cached_date_str, cached_remaining_str = cache_path.read_text().splitlines()
            cached_date = dt.date.fromisoformat(cached_date_str.strip())
            cached_remaining = int(cached_remaining_str.strip())
            if cached_date == current_date:
                used_today = max(cached_remaining - remaining, 0)
        except Exception:
            # Ignore malformed cache and reset it
            used_today = 0

    cache_path.write_text(f"{current_date.isoformat()}\n{remaining}\n")
    return used_today


def compute_usage_stats(
    snapshot: UsageSnapshot,
    used_today: int,
    now: Optional[dt.datetime] = None,
    workday_hours: tuple[int, int] = (9, 18),
) -> UsageComputation:
    now = now or dt.datetime.now(dt.timezone.utc)
    days_until_reset = calculate_days_until_reset(snapshot.reset_date, now)
    hours_until_reset = days_until_reset * 24

    if snapshot.unlimited:
        return UsageComputation(
            usage_pct=0.0,
            used=snapshot.used,
            used_today=used_today,
            days_until_reset=days_until_reset,
            hours_until_reset=hours_until_reset,
            daily_budget=0,
            hourly_budgets={"conservative": 0.0, "moderate": 0.0, "focused": 0.0},
            warning=None,
            status="unlimited",
        )

    usage_pct = 0.0
    if snapshot.limit:
        usage_pct = round((snapshot.used * 100) / snapshot.limit, 1)

    daily_budget = calculate_daily_budget(snapshot.remaining, days_until_reset)
    hourly_budgets = {
        "conservative": round(daily_budget / 12, 1),
        "moderate": round(daily_budget / 10, 1),
        "focused": round(daily_budget / 8, 1),
    }

    warning = None
    if snapshot.limit:
        warning_threshold = snapshot.limit * 0.25
        notice_threshold = snapshot.limit * 0.50
        if snapshot.remaining < warning_threshold:
            warning = "WARNING: Less than 25% of requests remaining"
        elif snapshot.remaining < notice_threshold:
            warning = "NOTICE: Less than 50% of requests remaining"

    status = "ok"
    if daily_budget == 0:
        status = "no_budget"
    elif used_today > daily_budget:
        status = "over_budget"
    elif used_today >= daily_budget * 0.75:
        status = "approaching"

    return UsageComputation(
        usage_pct=usage_pct,
        used=snapshot.used,
        used_today=used_today,
        days_until_reset=days_until_reset,
        hours_until_reset=hours_until_reset,
        daily_budget=daily_budget,
        hourly_budgets=hourly_budgets,
        warning=warning,
        status=status,
    )


def _color(text: str, code: str, enabled: bool) -> str:
    if not enabled:
        return text
    return f"\033[{code}m{text}\033[0m"


def _ensure_aware(dt_obj: dt.datetime) -> dt.datetime:
    if dt_obj.tzinfo is None:
        return dt_obj.replace(tzinfo=dt.timezone.utc)
    return dt_obj.astimezone(dt.timezone.utc)


def format_check_output(
    snapshot: UsageSnapshot,
    stats: UsageComputation,
    used_today: int,
    now: dt.datetime,
    color: bool = True,
) -> str:
    lines = [
        _color("=== GitHub Copilot Premium Request Usage ===", "34", color),
        "",
        f"User: {_color(snapshot.login, '32', color)}",
        f"Plan: {_color(snapshot.plan, '36', color)}",
        "",
    ]

    if snapshot.unlimited:
        lines.append(_color("✓ You have UNLIMITED premium requests!", "32", color))
        lines.append("No quota tracking needed.")
        return "\n".join(lines)

    lines.extend(
        [
            _color("Copilot Premium Model Requests:", "32", color),
            f"  Total Limit:      {snapshot.limit} requests",
            f"  Remaining:        {snapshot.remaining} requests",
            f"  Used:             {snapshot.used} requests",
            f"  Used today (UTC): {used_today} requests",
            f"  Usage:            {stats.usage_pct:.1f}%",
        ]
    )

    if stats.days_until_reset > 0:
        resets_at = dt.datetime.combine(snapshot.reset_date, dt.time(), tzinfo=dt.timezone.utc)
        lines.append(f"  Resets at:        {resets_at.strftime('%Y-%m-%d %H:%M:%S %Z')}")
        if stats.days_until_reset > 1:
            lines.append(f"  Time until reset: {round(stats.days_until_reset, 1)} days")
        else:
            lines.append(f"  Time until reset: {round(stats.hours_until_reset, 1)} hours")

    lines.append("")
    lines.append(_color("=== Daily Usage Recommendations ===", "33", color))

    if stats.daily_budget == 0:
        lines.append(_color("No usage data available.", "31", color))
        return "\n".join(lines)

    lines.append(
        f"  Recommended daily budget: {stats.daily_budget} requests/day"
    )
    lines.append(
        f"  Usage patterns:\n    Conservative (12h/day): ~{stats.hourly_budgets['conservative']} requests/hour"
    )
    lines.append(
        f"    Moderate (10h/day):     ~{stats.hourly_budgets['moderate']} requests/hour"
    )
    lines.append(
        f"    Focused (8h/day):       ~{stats.hourly_budgets['focused']} requests/hour"
    )

    lines.append("")
    if stats.status == "over_budget":
        lines.append(_color(f"Status: ⚠ Over budget by {used_today - stats.daily_budget} requests", "31", color))
    elif stats.status == "approaching":
        lines.append(
            _color(f"Status: ⚠ Used {used_today}/{stats.daily_budget} (approaching limit)", "33", color)
        )
    else:
        lines.append(_color(f"Status: ✓ Used {used_today}/{stats.daily_budget}", "32", color))

    if stats.warning:
        lines.append("")
        lines.append(_color(stats.warning, "31", color))
        if "25%" in stats.warning:
            lines.append(_color("Consider conserving requests until reset.", "33", color))

    return "\n".join(lines)


def _format_history_header() -> str:
    return "timestamp,limit,used,remaining,percent_used,days_until_reset,plan"


def append_history(
    history_path: Path,
    snapshot: UsageSnapshot,
    stats: UsageComputation,
    now: dt.datetime,
) -> tuple[str, Optional[int], Optional[dt.datetime]]:
    history_path.parent.mkdir(parents=True, exist_ok=True)
    previous_used: Optional[int] = None
    previous_timestamp: Optional[dt.datetime] = None

    if history_path.exists():
        lines = history_path.read_text().strip().splitlines()
        if lines and lines[0].startswith("timestamp") and len(lines) > 1:
            last = lines[-1].split(",")
            try:
                previous_used = int(last[2])
                previous_timestamp = _ensure_aware(dt.datetime.fromisoformat(last[0]))
            except Exception:
                previous_used = None
                previous_timestamp = None
    else:
        history_path.write_text(f"{_format_history_header()}\n")

    percent_used = stats.usage_pct
    record = ",".join(
        [
            now.isoformat(),
            str(snapshot.limit),
            str(snapshot.used),
            str(snapshot.remaining),
            f"{percent_used:.1f}",
            f"{stats.days_until_reset:.1f}",
            snapshot.plan,
        ]
    )
    with history_path.open("a", encoding="utf-8") as handle:
        handle.write(f"{record}\n")

    return record, previous_used, previous_timestamp


def format_track_output(
    snapshot: UsageSnapshot,
    stats: UsageComputation,
    history_result: tuple[str, Optional[int], Optional[dt.datetime]],
    now: dt.datetime,
    color: bool = True,
) -> str:
    record, previous_used, previous_timestamp = history_result
    now = _ensure_aware(now)
    lines = [
        _color("Usage recorded!", "32", color),
        "",
        "Current status:",
        f"  Limit:     {snapshot.limit}",
        f"  Used:      {snapshot.used} ({stats.usage_pct:.1f}%)",
        f"  Remaining: {snapshot.remaining}",
        f"  Resets in: {round(stats.days_until_reset, 1)} days",
        "",
        "History file:",
        f"  {record}",
    ]

    if previous_used is not None and previous_timestamp is not None:
        previous_timestamp = _ensure_aware(previous_timestamp)
        change = snapshot.used - previous_used
        if change > 0:
            lines.append(
                _color(
                    f"Used {change} requests since last check ({previous_timestamp.isoformat()})",
                    "32",
                    color,
                )
            )
            hours_diff = (now - previous_timestamp).total_seconds() / 3600
            if 0 < hours_diff < 48:
                rate = round(change / hours_diff, 1)
                lines.append(f"   Rate: {rate} requests/hour")
        elif change < 0:
            lines.append(_color("Monthly reset detected (quota refreshed)", "33", color))
        else:
            lines.append("No change since last check")

    return "\n".join(lines)


def run_check(
    fetcher: Optional[Callable[[], Dict]] = None,
    cache_path: Optional[Path] = None,
    now: Optional[dt.datetime] = None,
    color: bool = True,
) -> str:
    fetcher = fetcher or fetch_usage_via_gh
    cache_path = cache_path or Path("/tmp/gh-copilot-usage-tracker.txt")
    now = now or dt.datetime.now(dt.timezone.utc)

    payload = fetcher()
    snapshot = parse_usage_payload(payload)

    if snapshot.unlimited:
        stats = compute_usage_stats(snapshot, used_today=0, now=now)
        return format_check_output(snapshot, stats, 0, now, color)

    used_today = compute_used_today(cache_path, now.date(), snapshot.remaining)
    stats = compute_usage_stats(snapshot, used_today=used_today, now=now)

    return format_check_output(snapshot, stats, used_today, now, color)


def run_track(
    fetcher: Optional[Callable[[], Dict]] = None,
    history_path: Optional[Path] = None,
    now: Optional[dt.datetime] = None,
    color: bool = True,
) -> str:
    fetcher = fetcher or fetch_usage_via_gh
    history_path = history_path or Path(os.getenv("HISTORY_FILE", Path.home() / ".copilot-usage-history.csv"))
    now = now or dt.datetime.now(dt.timezone.utc)

    payload = fetcher()
    snapshot = parse_usage_payload(payload)
    stats = compute_usage_stats(snapshot, used_today=0, now=now)
    history_result = append_history(history_path, snapshot, stats, now)

    return format_track_output(snapshot, stats, history_result, now, color)


def fetch_usage_via_gh() -> Dict:
    gh = shutil.which("gh")
    if not gh:
        raise UsageError("gh CLI not found. Install GitHub CLI and login first.")

    proc = subprocess.run(
        [gh, "api", "/copilot_internal/user"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise UsageError(proc.stderr.strip() or "Unable to access Copilot usage API.")

    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise UsageError("Failed to parse API response.") from exc


def main(argv: Optional[Iterable[str]] = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Copilot usage tooling")
    parser.add_argument("--no-color", action="store_true", help="Disable colored output")

    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("check", help="Check current Copilot usage")
    subparsers.add_parser("track", help="Track Copilot usage history")

    args = parser.parse_args(list(argv) if argv is not None else None)
    color = not args.no_color

    try:
        if args.command == "check":
            print(run_check(color=color))
        elif args.command == "track":
            print(run_track(color=color))
    except UsageError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
