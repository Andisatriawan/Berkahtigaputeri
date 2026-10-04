#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

import requests
from openpyxl import load_workbook

EXCEL_PATH = Path(os.environ.get(
    "FINAL_POS_EXCEL",
    "config/FINAL_Production_Excel_A_WebC_Template_100Tenants.xlsx",
))
EXPECTED_KEYS = 352
TIMEOUT = 30


def as_json(value, key):
    if isinstance(value, dict):
        return value
    if value in (None, ""):
        return {}
    try:
        parsed = json.loads(str(value))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON for {key}: {exc}") from exc
    if not isinstance(parsed, dict):
        raise ValueError(f"Expected object for {key}")
    return parsed


def load_payloads():
    wb = load_workbook(EXCEL_PATH, read_only=True, data_only=True)
    required = {
        "README_PRODUCTION", "TEMPLATES", "GLOBAL", "TENANTS_MASTER",
        "DEVICES", "SERVICES", "APP_CONFIG_EXPORT",
    }
    missing = required.difference(wb.sheetnames)
    if missing:
        raise ValueError(f"Missing sheets: {sorted(missing)}")

    ws = wb["APP_CONFIG_EXPORT"]
    headers = [str(v).strip() for v in next(ws.iter_rows(values_only=True))]
    payloads = {}
    for row in ws.iter_rows(min_row=2, values_only=True):
        item = dict(zip(headers, row))
        key = str(item.get("key") or "").strip()
        if not key:
            continue
        payloads[key] = as_json(item.get("value_jsonb"), key)

    if len(payloads) != EXPECTED_KEYS:
        raise ValueError(f"Expected {EXPECTED_KEYS} unique keys, got {len(payloads)}")

    global_value = {}
    for field, value, *_ in wb["GLOBAL"].iter_rows(min_row=2, values_only=True):
        if field is not None:
            global_value[str(field)] = value
    payloads["global"] = {**global_value, **payloads.get("global", {})}

    rows = list(wb["TEMPLATES"].iter_rows(values_only=True))
    th = [str(v).strip() for v in rows[0]]
    for values in rows[1:]:
        item = dict(zip(th, values))
        template_id = str(item["template_id"]).strip().upper()
        fields = as_json(item.get("43_fields_json"), f"template:{template_id}")
        canonical = {
            "template_id": template_id,
            "template_name": item.get("template_name"),
            "price": item.get("price_per_month"),
            "price_per_month": item.get("price_per_month"),
            "max_user": item.get("max_user"),
            "mdr": item.get("mdr_pos_%"),
            "mdr_pos": item.get("mdr_pos_%"),
            "mdr_akuntansi": item.get("mdr_akuntansi_%"),
            "features": {
                "pos": bool(item.get("features_pos")),
                "akuntansi": bool(item.get("features_akuntansi")),
                "api": bool(item.get("features_api")),
            },
            "tenants_count": item.get("tenants_count"),
            "description": item.get("description"),
            "fields": fields,
            **fields,
        }
        payloads[f"template:{template_id}"] = {
            **canonical,
            **payloads.get(f"template:{template_id}", {}),
            "mdr": item.get("mdr_pos_%"),
            "mdr_pos": item.get("mdr_pos_%"),
        }

    return [{"key": key, "value": value} for key, value in payloads.items()]


def sync_rows(rows, url, service_key):
    endpoint = f"{url.rstrip('/')}/rest/v1/app_config"
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }
    for start in range(0, len(rows), 100):
        batch = rows[start:start + 100]
        response = requests.post(
            endpoint,
            params={"on_conflict": "key"},
            headers=headers,
            json=batch,
            timeout=TIMEOUT,
        )
        if not response.ok:
            detail = response.text.strip().replace("\n", " ")[:1000]
            raise RuntimeError(
                f"Supabase REST upsert failed HTTP {response.status_code}: {detail}"
            )


def main():
    url = os.environ.get("SUPABASE_URL", "").strip()
    service_key = os.environ.get("SUPABASE_SERVICE_KEY", "").strip()

    if not url or not service_key:
        print(
            "WARNING: SUPABASE_URL or SUPABASE_SERVICE_KEY missing; "
            "sync skipped and exits GREEN."
        )
        return 0

    if not EXCEL_PATH.exists():
        print(f"ERROR: Excel not found: {EXCEL_PATH}", file=sys.stderr)
        return 2

    try:
        rows = load_payloads()
        sync_rows(rows, url, service_key)
    except (ValueError, RuntimeError, requests.RequestException) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 3

    print(f"DONE Synced {len(rows)} keys")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
