import copy
import datetime as dt
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def _base_payload():
    return {
        "login": "username",
        "copilot_plan": "individual_pro",
        "quota_reset_date": "2026-03-01",
        "quota_snapshots": {
            "premium_interactions": {
                "entitlement": 1500,
                "remaining": 1054,
                "percent_remaining": 70.28,
                "unlimited": False,
            }
        },
    }


@pytest.fixture
def sample_payload():
    return _base_payload()


@pytest.fixture
def unlimited_payload():
    payload = _base_payload()
    payload["quota_snapshots"]["premium_interactions"]["unlimited"] = True
    payload["quota_snapshots"]["premium_interactions"]["entitlement"] = 0
    payload["quota_snapshots"]["premium_interactions"]["remaining"] = 0
    payload["quota_snapshots"]["premium_interactions"]["percent_remaining"] = 100
    return payload


@pytest.fixture
def now():
    return dt.datetime(2026, 2, 10, 12, 0, 0, tzinfo=dt.timezone.utc)
