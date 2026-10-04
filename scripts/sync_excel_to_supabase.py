#!/usr/bin/env python3
"""Sync the FINAL Pos workbook to Supabase app_config through PostgREST."""

import json
import os
import sys
from pathlib import Path
from typing import Any

import requests
from openpyxl import load_workbook

EXCEL_PATH = Path(
    os.environ.get(
        "FINAL_POS_EXCEL",
        "config/FINAL_Production_Excel_A_WebC_Template_100Tenants.xlsx",
    )
)
EXPECTED_SHEETS = [
    "README_PRODUCTION",
    "TEMPLATES",
    "GLOBAL",
    "TENANTS_MASTER",
    "DEVICES",
    "SERVICES",
    "APP_CONFIG_EXPORT",
]
EXPECTED_COUNTS = {
    "global": 1,
    "template": 3,
    "tenant": 100,
    "service": 140,
    "device": 108,
}
EXPECTED_TEMPLATES = {"BASIC", "PRO", "ENTERPRISE"}
EXPECTED_KEYS = 352
BATCH_SIZE = 100
REQUEST_TIMEOUT_SECONDS = 30


def _rows_as_dicts(ws) -> list[dict[str, Any]]:
    rows = list(ws.iter_rows(values_only=True))
    if not rows:
        return []
    headers = [str(value).strip() if value is not None else "" for value in rows[0]]
    result: list[dict[str, Any]] = []
    for row in rows[1:]:
        if all(value is None for value in row):
            continue
        result.append({headers[index]: row[index] for index in range(len(headers))})
    return result


def _decode_json(raw: Any, key: str) -> dict[str, Any]:
    if isinstance(raw, dict):
        value = raw
    else:
        try:
            value = json.loads(str(raw))
        except (TypeError, json.JSONDecodeError) as exc:
            raise ValueError(f"Invalid value_jsonb for {key}: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"value_jsonb for {key} must be a JSON object")
    return value


def load_payloads() -> list[dict[str, Any]]:
    if not EXCEL_PATH.exists():
        raise FileNotFoundError(f"Excel not found: {EXCEL_PATH}")

    wb = load_workbook(EXCEL_PATH, read_only=True, data_only=True)
    if wb.sheetnames != EXPECTED_SHEETS:
        raise ValueError(f"Unexpected sheet layout: {wb.sheetnames}")

    template_rows = _rows_as_dicts(wb["TEMPLATES"])
    template_ids = {
        str(row.get("template_id") or "").strip().upper()
        for row in template_rows
    }
    if template_ids != EXPECTED_TEMPLATES:
        raise ValueError(f"Unexpected template IDs: {sorted(template_ids)}")

    if len(_rows_as_dicts(wb["TENANTS_MASTER"])) != 100:
        raise ValueError("TENANTS_MASTER must contain exactly 100 tenants")
    if len(_rows_as_dicts(wb["DEVICES"])) != 108:
        raise ValueError("DEVICES must contain exactly 108 devices")
    if len(_rows_as_dicts(wb["SERVICES"])) != 140:
        raise ValueError("SERVICES must contain exactly 140 service rows")

    global_rows = list(wb["GLOBAL"].iter_rows(min_row=2, values_only=True))
    if not global_rows:
        raise ValueError("GLOBAL sheet is empty")

    export_rows = _rows_as_dicts(wb["APP_CONFIG_EXPORT"])
    if len(export_rows) != EXPECTED_KEYS:
        raise ValueError(
            f"APP_CONFIG_EXPORT must contain {EXPECTED_KEYS} rows; got {len(export_rows)}"
        )

    payloads: list[dict[str, Any]] = []
    seen: set[str] = set()
    counts = {kind: 0 for kind in EXPECTED_COUNTS}

    for row in export_rows:
        key = str(row.get("key") or "").strip()
        kind = str(row.get("type") or "").strip().lower()
        status = str(row.get("sync_status") or "").strip().upper()

        if not key:
            raise ValueError("APP_CONFIG_EXPORT contains an empty key")
        if key in seen:
            raise ValueError(f"Duplicate app_config key: {key}")
        if kind not in counts:
            raise ValueError(f"Unsupported app_config type for {key}: {kind}")
        if status and status != "READY":
            raise ValueError(f"app_config key {key} is not READY: {status}")

        seen.add(key)
        counts[kind] += 1
        payloads.append({"key": key, "value": _decode_json(row.get("value_jsonb"), key)})

    if counts != EXPECTED_COUNTS:
        raise ValueError(f"APP_CONFIG_EXPORT type counts mismatch: {counts}")

    required = {
        "global",
        "template:BASIC",
        "template:PRO",
        "template:ENTERPRISE",
        "tenant:tenant_001",
        "tenant:tenant_001:service:pos",
        "device:infinix_001_410",
    }
    missing = required.difference(seen)
    if missing:
        raise ValueError(f"Missing required app_config keys: {sorted(missing)}")

    return payloads


def sync(payloads: list[dict[str, Any]], url: str, service_key: str) -> None:
    endpoint = f"{url.rstrip('/')}/rest/v1/app_config"
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
        "User-Agent": "berkahtigaputeri-final-pos-sync/2.0",
    }

    for start in range(0, len(payloads), BATCH_SIZE):
        batch = payloads[start : start + BATCH_SIZE]
        response = requests.post(
            endpoint,
            params={"on_conflict": "key"},
            headers=headers,
            json=batch,
            timeout=REQUEST_TIMEOUT_SECONDS,
        )
        if not response.ok:
            detail = response.text.strip().replace("\n", " ")[:1000]
            raise RuntimeError(
                f"Supabase REST upsert failed: HTTP {response.status_code}: {detail}"
            )


def main() -> int:
    url = os.environ.get("SUPABASE_URL", "").strip()
    service_key = os.environ.get("SUPABASE_SERVICE_KEY", "").strip()

    if not url or not service_key:
        print(
            "WARNING: SUPABASE_URL or SUPABASE_SERVICE_KEY missing; "
            "sync skipped and workflow remains GREEN."
        )
        return 0

    try:
        payloads = load_payloads()
        sync(payloads, url, service_key)
    except (FileNotFoundError, ValueError, RuntimeError, requests.RequestException) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(f"DONE Synced {len(payloads)} keys")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
