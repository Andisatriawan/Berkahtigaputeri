#!/usr/bin/env python3
"""Static contract checks for the Phase 5 Supabase tenant-isolation migration."""
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20261013120000_phase5_tenant_isolation_hardening.sql"
TEST_SQL = ROOT / "supabase/tests/tenant_isolation.test.sql"
CONFIG_SERVICE = ROOT / "pos-app/lib/core/config/config_service.dart"

def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)

def require(text: str, fragment: str, source: str) -> None:
    if fragment.casefold() not in text.casefold():
        fail(f"{source} is missing required contract fragment: {fragment}")

def main() -> int:
    migration = MIGRATION.read_text(encoding="utf-8")
    test_sql = TEST_SQL.read_text(encoding="utf-8")
    config_service = CONFIG_SERVICE.read_text(encoding="utf-8")

    for fragment in (
        "revoke all privileges on table",
        "from anon, public",
        "enable row level security",
        "create policy",
        "to authenticated",
        "auth.uid()",
        "private.assert_app_config_inventory()",
        "1fd3d64219ecc7c333453c20da80e295",
        "device does not belong to tenant",
        "caller is not authorized for device",
        "tenant:' || p_tenant || ':service:' || svc",
        "g || x || t || s || d",
        "revoke all on function public.get_effective_config(text, text, text) from public, anon",
        "grant execute on function public.get_effective_config(text, text, text) to authenticated, service_role",
    ):
        require(migration, fragment, str(MIGRATION.relative_to(ROOT)))

    for fragment in (
        "plan(27)",
        "has_table_privilege('anon'",
        "has_function_privilege('anon'",
        "request.jwt.claims",
        "tenant A cannot see tenant b metadata",
        "other-tenant config is not directly readable",
        "effective-config exactly matches global/template/tenant/pos/device",
        "effective-config exactly matches global/template/tenant/akuntansi/device",
        "throws_ok(",
        "42501",
        "rollback;",
    ):
        require(test_sql, fragment, str(TEST_SQL.relative_to(ROOT)))

    require(config_service, "_client.rpc(", str(CONFIG_SERVICE.relative_to(ROOT)))
    require(config_service, "hasAuthenticatedSession", str(CONFIG_SERVICE.relative_to(ROOT)))
    require(config_service, "for this exact tenant/device/service tuple", str(CONFIG_SERVICE.relative_to(ROOT)))
    if ".from('app_config')" in config_service or "_fallbackSelectAndMerge" in config_service:
        fail("ConfigService must not directly SELECT raw app_config layers as a client fallback")

    if "auth.role()" in migration:
        fail("migration must use explicit TO roles and auth.uid(), not deprecated auth.role()")

    print("PASS: Phase 5 source contract, SQL-test assertions, and RPC-only Flutter access")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
