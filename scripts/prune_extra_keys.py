#!/usr/bin/env python3
"""Prune non-canonical app_config rows using the Final Pos workbook as authority.

Dry-run is the default. Destructive deletion requires --apply plus explicit expected
preconditions, so an unexpected database state fails closed before any DELETE.
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import Any

import requests

import sync_excel_to_supabase_legacy as legacy

EXPECTED_CANONICAL_KEYS = 352
REQUEST_TIMEOUT_SECONDS = legacy.REQUEST_TIMEOUT_SECONDS


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Actually delete non-canonical rows")
    parser.add_argument(
        "--expected-before",
        type=int,
        default=None,
        help="Required remote app_config count before deletion when --apply is used",
    )
    parser.add_argument(
        "--expected-extra-count",
        type=int,
        default=None,
        help="Required number of non-canonical rows when --apply is used",
    )
    return parser.parse_args()


def headers(service_key: str) -> dict[str, str]:
    return {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Accept": "application/json",
        "Content-Type": "application/json",
        "User-Agent": "berkahtigaputeri-final-pos-prune/1.0",
    }


def fetch_remote_keys(url: str, service_key: str) -> list[str]:
    response = requests.get(
        f"{url.rstrip('/')}/rest/v1/app_config",
        params={"select": "key", "limit": "1000"},
        headers=headers(service_key),
        timeout=REQUEST_TIMEOUT_SECONDS,
    )
    if not response.ok:
        raise RuntimeError(
            f"Unable to list app_config: HTTP {response.status_code}: {response.text[:1000]}"
        )
    data: Any = response.json()
    if not isinstance(data, list):
        raise RuntimeError("Unexpected app_config list response")
    keys = [str(row.get("key")) for row in data if isinstance(row, dict) and row.get("key")]
    if len(keys) != len(set(keys)):
        raise RuntimeError("Duplicate app_config keys returned by REST")
    return keys


def delete_key(url: str, service_key: str, key: str) -> None:
    response = requests.delete(
        f"{url.rstrip('/')}/rest/v1/app_config",
        params={"key": f"eq.{key}"},
        headers={**headers(service_key), "Prefer": "return=representation"},
        timeout=REQUEST_TIMEOUT_SECONDS,
    )
    if not response.ok:
        raise RuntimeError(
            f"DELETE failed for {key}: HTTP {response.status_code}: {response.text[:1000]}"
        )
    data: Any = response.json()
    if not isinstance(data, list) or len(data) != 1 or data[0].get("key") != key:
        raise RuntimeError(f"DELETE for {key} did not delete exactly that row")


def main() -> int:
    args = parse_args()
    url = os.environ.get("SUPABASE_URL", "").strip()
    service_key = os.environ.get("SUPABASE_SERVICE_KEY", "").strip()
    if not url or not service_key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_KEY are required")

    payloads = legacy.load_workbook_payloads()
    canonical = {str(row["key"]) for row in payloads.app_config}
    if len(canonical) != EXPECTED_CANONICAL_KEYS:
        raise RuntimeError(
            f"Workbook safety check failed: expected {EXPECTED_CANONICAL_KEYS} canonical keys, "
            f"got {len(canonical)}"
        )

    remote = fetch_remote_keys(url, service_key)
    extras = sorted(set(remote) - canonical)
    missing = sorted(canonical - set(remote))

    print(f"Canonical workbook keys: {len(canonical)}")
    print(f"Remote app_config keys: {len(remote)}")
    print(f"Non-canonical extras: {len(extras)}")
    for key in extras:
        print(f"EXTRA {key}")
    if missing:
        print(f"Missing canonical keys: {len(missing)}")
        for key in missing[:20]:
            print(f"MISSING {key}")
        raise RuntimeError("Refusing prune while canonical workbook keys are missing remotely")

    if not args.apply:
        print("DRY-RUN ONLY: pass --apply with expected preconditions to delete extras")
        return 0

    if args.expected_before is None or args.expected_extra_count is None:
        raise RuntimeError(
            "--apply requires --expected-before and --expected-extra-count for fail-closed safety"
        )
    if len(remote) != args.expected_before:
        raise RuntimeError(
            f"Precondition failed: expected {args.expected_before} remote keys, got {len(remote)}"
        )
    if len(extras) != args.expected_extra_count:
        raise RuntimeError(
            f"Precondition failed: expected {args.expected_extra_count} extras, got {len(extras)}"
        )

    for key in extras:
        if key in canonical:
            raise RuntimeError(f"Internal safety error: refusing to delete canonical key {key}")
        delete_key(url, service_key, key)
        print(f"DELETED {key}")

    remaining = fetch_remote_keys(url, service_key)
    remaining_extras = sorted(set(remaining) - canonical)
    if len(remaining) != EXPECTED_CANONICAL_KEYS or remaining_extras:
        raise RuntimeError(
            f"Post-prune verification failed: count={len(remaining)} extras={remaining_extras}"
        )

    print(f"PRUNE OK: app_config {args.expected_before} -> {len(remaining)}")
    print("Canonical app_config count verified: 352")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
