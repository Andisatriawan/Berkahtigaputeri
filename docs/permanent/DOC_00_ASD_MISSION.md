# DOC_00_ASD_MISSION - PERSISTENT MISSION FOR PROMPT "asd"
> TRIGGER: When user says "asd", "ASD", "lanjut", "continue mission" -> YOU MUST EXECUTE THIS MISSION TILL END.

**Repo:** berkah-ajb-dev/Berkahtigaputeri
**Main HEAD:** 68826ec66e220b82f40c022bc27fa9a3f24b0f2b
**Status:** 17 branches, CI GREEN but 18 alignment issues (8 HIGH, 6 MED, 4 LOW)
**Source of audit:** Full repo sync audit 16m43s - report in conversation history

## MISSION OBJECTIVE
Make repository 100% synchronized: Docs == Code == Workflows == RLS == UAT.
Not just fix, but systemic persistence on main.

## URGENT GENERAL REQUIREMENTS FIRST (Phase 1)
These 3 block UAT completely:

**[P0-1] HIGH-1 Auth vs RLS:** pos-app/lib/main.dart has no auth, but final RLS denies anon.
-> Fix: Create device provisioning flow before ConfigService, bind devices.user_id

**[P0-2] HIGH-2 Migration broken:** DOC_02_SUPABASE_SCHEMA_V1.sql missing devices.user_id/platform but next migration ALTERs them
-> Fix: Make migration ADD COLUMN IF NOT EXISTS

**[P0-3] HIGH-6 Feature flags dual authority:** Admin writes tenants.features, APK reads app_config
-> Fix: Move Admin to update_app_config_atomic RPC, keep tenants.features as projection only

## PHASE 2 - HIGH REMAINING
- [P1-4] DOC_02/DOC_04 verification still 3-layer, need 5-layer: GLOBAL->TEMPLATE->TENANT->SERVICE->DEVICE
- [P1-5] DOC_03 verification expects anon SELECT allowed but RLS denies
- [P1-6] DOC_07_FINAL_VERIFICATION_CURRENT_HEAD.md points to deleted branch fix/final-pos-canonical-sync, not main@68826ec
- [P1-7] Doc-Workflow fail-closed overstated - PRs skip live secret check

## PHASE 3 - MEDIUM (Parity)
- [P2] config_service.dart fallback not normalize service (POS vs pos)
- [P2] inherited_from_template null vs empty string parity
- [P2] config_service_test.dart still tests 4 layers not 5
- [P2] DOC_05_FEATURE_FLAGS.sql bypasses atomic RPC
- [P2] legacy sync_excel_to_supabase_legacy.py bypasses versioning

## PHASE 4 - LOW
- [P3] home_screen.dart string "config 3 layer" -> "5 layer"
- [P3] app_version='a19cb3f' legacy seed
- [P3] build.yml Flutter not pinned, main.dart hardcoded defaults

## EXECUTION PROTOCOL FOR "asd"
1. git fetch --prune && git checkout main && git pull --ff-only
2. Read this file + docs/permanent/DOC_07_FINAL_VERIFICATION_CURRENT_HEAD.md + audit report
3. Pick next unchecked item from PHASE 1 -> 2 -> 3 -> 4
4. Fix code/docs/workflows accordingly
5. Update this file: check [x] and add log entry below
6. Commit: git add -A && git commit -m "fix(asd): [P0-1] description" && git push origin main
7. Run: gh run list --branch main --limit 3
8. If not all done, continue loop. NEVER stop at 1 fix.

## STATE LOG
- [x] 2026-10-05 main@68826ec audit 18 issues found, CI green
- [x] 2026-10-05 cleanup 27->17 branches, main tracking fixed
- [ ] P0-1 auth provisioning - TODO
- [ ] P0-2 migration self-contained - TODO
- [ ] P0-3 feature flags authority - TODO
-... (update as you go)

## DONE CRITERIA
All 18 issues checked [x], fresh DB rebuild works, fresh APK can auth -> config, Admin toggle == APK value, DOC_07 recertified at new main SHA, gh pr checks 7/7 green.
