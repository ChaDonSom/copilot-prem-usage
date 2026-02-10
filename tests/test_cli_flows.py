import copy
import datetime as dt

from copilot_usage import run_check, run_track


def test_run_check_outputs_key_lines(sample_payload, now, tmp_path):
    output = run_check(
        fetcher=lambda: sample_payload,
        cache_path=tmp_path / "cache.txt",
        now=now,
        color=False,
    )

    assert "Total Limit:      1500 requests" in output
    assert "Recommended daily budget: 58 requests/day" in output
    assert "Usage:            29.7%" in output


def test_run_check_warns_when_low_quota(sample_payload, now, tmp_path):
    def low_fetcher():
        payload = copy.deepcopy(sample_payload)
        payload["quota_snapshots"]["premium_interactions"]["remaining"] = 200
        payload["quota_snapshots"]["premium_interactions"]["percent_remaining"] = 13.3
        return payload

    output = run_check(
        fetcher=low_fetcher,
        cache_path=tmp_path / "cache.txt",
        now=now,
        color=False,
    )

    assert "WARNING: Less than 25% of requests remaining" in output


def test_run_track_appends_history_and_detects_change(sample_payload, now, tmp_path):
    history_path = tmp_path / "history.csv"

    first = run_track(
        fetcher=lambda: sample_payload,
        history_path=history_path,
        now=now,
        color=False,
    )

    second_payload = copy.deepcopy(sample_payload)
    second_payload["quota_snapshots"]["premium_interactions"]["remaining"] = 1044
    later = now + dt.timedelta(hours=1)

    second = run_track(
        fetcher=lambda: second_payload,
        history_path=history_path,
        now=later,
        color=False,
    )

    assert "Usage recorded" in first
    assert "Usage recorded" in second
    assert "Used 10 requests since last check" in second


def test_run_track_handles_naive_history_timestamp(sample_payload, now, tmp_path):
    history_path = tmp_path / "history.csv"
    history_path.write_text(
        "timestamp,limit,used,remaining,percent_used,days_until_reset,plan\n"
        "2026-02-10T12:00:00,1500,446,1054,29.7,18.5,individual_pro\n"
    )

    payload = copy.deepcopy(sample_payload)
    payload["quota_snapshots"]["premium_interactions"]["remaining"] = 1044
    later = dt.datetime(2026, 2, 10, 13, 0, 0, tzinfo=dt.timezone.utc)

    output = run_track(
        fetcher=lambda: payload,
        history_path=history_path,
        now=later,
        color=False,
    )

    assert "Used 10 requests since last check" in output
