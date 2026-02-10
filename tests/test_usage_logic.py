import datetime as dt
from pathlib import Path

import pytest

from copilot_usage import (
    calculate_daily_budget,
    calculate_days_until_reset,
    compute_usage_stats,
    compute_used_today,
    parse_usage_payload,
)


def test_parse_usage_payload_extracts_fields(sample_payload):
    snapshot = parse_usage_payload(sample_payload)

    assert snapshot.login == "username"
    assert snapshot.plan == "individual_pro"
    assert snapshot.limit == 1500
    assert snapshot.remaining == 1054
    assert snapshot.percent_remaining == pytest.approx(70.28)
    assert snapshot.unlimited is False
    assert snapshot.reset_date == dt.date(2026, 3, 1)


def test_parse_usage_payload_handles_unlimited(unlimited_payload):
    snapshot = parse_usage_payload(unlimited_payload)

    assert snapshot.unlimited is True
    assert snapshot.limit == 0
    assert snapshot.remaining == 0
    assert snapshot.percent_remaining == 100


def test_calculate_days_until_reset(sample_payload, now):
    snapshot = parse_usage_payload(sample_payload)
    days = calculate_days_until_reset(snapshot.reset_date, now)

    assert days == pytest.approx(18.5, rel=0.05)


def test_calculate_daily_budget_rounds_down():
    assert calculate_daily_budget(1054, 18) == 58
    assert calculate_daily_budget(200, 0) == 0


def test_compute_used_today_tracks_across_days(tmp_path):
    cache_path = tmp_path / "cache.txt"
    today = dt.date(2026, 2, 10)

    first = compute_used_today(cache_path, today, remaining=1000)
    second = compute_used_today(cache_path, today, remaining=990)
    tomorrow = compute_used_today(cache_path, today + dt.timedelta(days=1), remaining=980)

    assert first == 0
    assert second == 10
    assert tomorrow == 0


def test_compute_usage_stats_generates_budgets(sample_payload, now):
    snapshot = parse_usage_payload(sample_payload)
    stats = compute_usage_stats(snapshot, used_today=4, now=now)

    assert stats.daily_budget == 58
    assert stats.usage_pct == pytest.approx(29.7, rel=0.01)
    assert stats.hourly_budgets["moderate"] == pytest.approx(5.8, rel=0.01)
    assert stats.warning is None
