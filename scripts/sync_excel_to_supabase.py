#!/usr/bin/env python3
"""Validate and sync the FINAL Pos workbook with atomic app_config versioning.

Workbook parsing and relational projections remain in sync_excel_to_supabase_legacy.
Phase 6 owns the canonical entry point so existing app_config rows are updated only
through update_app_config_atomic(key, new_value, expected_version).
"""

from __future__ import annotations

from typing import Any

import requests

import sync_excel_to_supabase_legacy as legacy

REQUEST_TIMEOUT_SECONDS = legacy.REQUEST_TIMEOUT_SECONDS


def _rpc_headers(service_key: str) -> dict[str, str]:
    return {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "berkahtigaputeri-final-pos-sync/6.0",
    }


def _positive_version(value: Any, *, key: str) -> int:
    if not isinstance(value, dict):
        raise RuntimeError(f"app_config {key} value must be a JSON object")
    raw = value.get("version")
    if isinstance(raw, bool):
        raise RuntimeError(f"app_config {key} has invalid version {raw!r}")
    try:
        version = int(raw)
    except (TypeError, ValueError) as exc:
        raise RuntimeError(f"app_config {key} has missing/invalid version {raw!r}") from exc
    if version < 1 or str(raw).strip() not in {str(version), f"{version}.0"}:
        raise RuntimeError(f"app_config {key} has invalid version {raw!r}")
    return version


def _atomic_update(
    *,
    key: str,
    new_value: dict[str, Any],
    expected_version: int,
    url: str,
    service_key: str,
) -> dict[str, Any]:
    response = requests.post(
        f"{url.rstrip('/')}/rest/v1/rpc/update_app_config_atomic",
        headers=_rpc_headers(service_key),
        json={
            "key": key,
            "new_value": new_value,
            "expected_version": expected_version,
        },
        timeout=REQUEST_TIMEOUT_SECONDS,
    )
    if not response.ok:
        detail = response.text.strip().replace("\n", " ")[:1000]
        raise RuntimeError(
            f"Atomic app_config update failed for {key}: "
            f"HTTP {response.status_code}: {detail}"
        )
    data = response.json()
    if isinstance(data, list) and len(data) == 1:
        data = data[0]
    if not isinstance(data, dict):
        raise RuntimeError(f"Unexpected atomic RPC response for {key}")
    stored = data.get("value")
    version = _positive_version(stored, key=key)
    if version != expected_version + 1:
        raise RuntimeError(
            f"Atomic RPC returned wrong version for {key}: "
            f"expected {expected_version + 1}, got {version}"
        )
    return data


def _bootstrap_insert(
    *,
    key: str,
    new_value: dict[str, Any],
    url: str,
    service_key: str,
) -> None:
    # RPC is deliberately UPDATE-only. A genuinely missing canonical row may be
    # bootstrapped once at version 1; every subsequent write is compare-and-swap.
    value = dict(new_value)
    value["version"] = 1
    response = requests.post(
        f"{url.rstrip('/')}/rest/v1/app_config",
        headers={
            **_rpc_headers(service_key),
            "Prefer": "return=minimal",
        },
        json={"key": key, "value": value},
        timeout=REQUEST_TIMEOUT_SECONDS,
    )
    if not response.ok:
        detail = response.text.strip().replace("\n", " ")[:1000]
        raise RuntimeError(
            f"Bootstrap app_config insert failed for {key}: "
            f"HTTP {response.status_code}: {detail}"
        )


def _sync_app_config_atomic(
    rows: list[dict[str, Any]],
    *,
    url: str,
    service_key: str,
) -> None:
    remote_rows = legacy._fetch_rows(
        table="app_config",
        select="key,value",
        url=url,
        service_key=service_key,
    )
    remote = {
        str(row.get("key")): row
        for row in remote_rows
        if row.get("key") is not None
    }

    updated = 0
    inserted = 0
    for payload in rows:
        key = str(payload["key"])
        new_value = payload["value"]
        current = remote.get(key)
        if current is None:
            _bootstrap_insert(
                key=key,
                new_value=new_value,
                url=url,
                service_key=service_key,
            )
            inserted += 1
            continue

        expected_version = _positive_version(current.get("value"), key=key)
        result = _atomic_update(
            key=key,
            new_value=new_value,
            expected_version=expected_version,
            url=url,
            service_key=service_key,
        )
        remote[key] = {"key": key, "value": result["value"]}
        updated += 1

    print(
        "VERSIONED app_config sync: "
        f"atomic_updates={updated} bootstrap_inserts={inserted}"
    )


def _verify_versions(
    payloads: legacy.WorkbookPayloads,
    *,
    url: str,
    service_key: str,
) -> None:
    rows = legacy._fetch_rows(
        table="app_config",
        select="key,value",
        url=url,
        service_key=service_key,
    )
    by_key = {str(row.get("key")): row for row in rows if row.get("key") is not None}
    for payload in payloads.app_config:
        key = str(payload["key"])
        row = by_key.get(key)
        if row is None:
            raise RuntimeError(f"Post-sync app_config row missing: {key}")
        _positive_version(row.get("value"), key=key)
    print(f"VERIFIED positive versions on {len(payloads.app_config)} canonical app_config rows")


def sync(payloads: legacy.WorkbookPayloads, url: str, service_key: str) -> None:
    # Relational ownership remains workbook-driven and keeps the Phase 2 merge behavior.
    legacy._upsert(
        table="tenants",
        rows=payloads.tenants,
        on_conflict="tenant_id",
        url=url,
        service_key=service_key,
    )
    legacy._upsert(
        table="tenant_services",
        rows=payloads.services,
        on_conflict="tenant_id,service",
        url=url,
        service_key=service_key,
    )
    legacy._upsert(
        table="devices",
        rows=payloads.devices,
        on_conflict="device_id",
        url=url,
        service_key=service_key,
    )

    _sync_app_config_atomic(payloads.app_config, url=url, service_key=service_key)
    legacy.verify_remote(payloads, url, service_key)
    _verify_versions(payloads, url=url, service_key=service_key)


# Preserve the Phase 2 parser/CLI while replacing only its network sync function.
legacy.sync = sync

# Import-friendly aliases for callers/tests that used the canonical module before Phase 6.
WorkbookPayloads = legacy.WorkbookPayloads
load_workbook_payloads = legacy.load_workbook_payloads
parse_args = legacy.parse_args
main = legacy.main


if __name__ == "__main__":
    raise SystemExit(main())
