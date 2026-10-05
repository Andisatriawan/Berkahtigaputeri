# DOC_00_ASD_MISSION - PERSISTENT MISSION FOR TRIGGER "asd"
> **TRIGGER:** User says "asd" | "ASD" | "lanjut misi" => YOU MUST READ THIS FILE AND CONTINUE MISSION TILL END. DO NOT ASK.

**Repo:** berkah-ajb-dev/Berkahtigaputeri
**Base HEAD audited:** 68826ec66e220b82f40c022bc27fa9a3f24b0f2b (17 branches, CI 7/7 green)
**Audit result:** 18 issues - 8 HIGH, 6 MED, 4 LOW - repo green but NOT synchronized
**Full audit:** See DOC_08_AUDIT_18_ISSUES.md in same folder

## MISSION: Make repo 100% synchronized (Docs == Code == Workflows == RLS == UAT) + persistence on main

### PHASE 0 - PERSISTENCE (THIS FILE) [DONE after merge]
- [x] Create DOC_00_ASD_MISSION.md on main
- [x] Create DOC_08_AUDIT_18_ISSUES.md
- [x] Create.github/ASD_PROMPT.md as quick trigger

### PHASE 1 - URGENT GENERAL REQUIREMENTS (P0) - UAT BLOCKER
- [x] **P0-1 HIGH-1 Auth vs RLS:** FIXED - DeviceAuthService + ProvisioningScreen + AuthGate in main.dart
  Fix: Add device provisioning/sign-in before ConfigService, bind devices.user_id
  Files: pos-app/lib/main.dart:9-23, DOC_03_RLS_AUTH.sql

- [x] **P0-2 HIGH-2 Migration broken:** FIXED - ADD COLUMN IF NOT EXISTS user_id/platform in ownership migration
  Fix: ADD COLUMN IF NOT EXISTS user_id uuid, platform text in ownership migration

- [ ] **P0-3 HIGH-6 Feature flags dual authority:** btp-admin/feature-flags.js writes tenants.features, APK reads app_config first
  Fix: Admin must use update_app_config_atomic RPC, tenants.features = projection only

### PHASE 2 - HIGH (Doc-Doc / Doc-Workflow)
- [ ] P1-4 DOC_02_VERIFICATION.md still 3-layer, need 5-layer GLOBAL->TEMPLATE->TENANT->SERVICE->DEVICE
- [ ] P1-5 DOC_03_VERIFICATION.md expects anon SELECT allowed but RLS denies
- [ ] P1-6 DOC_04_VERIFICATION.md counts 5 keys with POS+Akuntansi together, missing TEMPLATE
- [ ] P1-7 DOC_07_FINAL_VERIFICATION_CURRENT_HEAD.md points to deleted branch fix/final-pos-canonical-sync, not main@68826ec
- [ ] P1-8 DOC_07 overstates fail-closed: PRs skip live Supabase check (final-pos-sync.yml dry-run only)

### PHASE 3 - MEDIUM (Parity bugs)
- [ ] MED-10 config_service.dart fallback not normalize service (POS vs pos) - add normalizeService()
- [ ] MED-11 inherited_from_template null vs empty string parity Flutter vs SQL
- [ ] MED-12 config_service_test.dart tests only 4 layers, missing TEMPLATE
- [ ] MED-13 DOC_05_FEATURE_FLAGS.sql uses INSERT ON CONFLICT instead of atomic RPC
- [ ] MED-14 scripts/sync_excel_to_supabase_legacy.py bypasses versioning

### PHASE 4 - LOW (Reproducibility)
- [ ] LOW-15 home_screen.dart:269 "config 3 layer" -> "5 layer"
- [ ] LOW-16 devices app_version='a19cb3f' legacy seed vs pubspec 1.0.0+2
- [ ] LOW-17 build.yml Flutter channel: stable not pinned
- [ ] LOW-18 main.dart hardcoded SUPABASE defaults, no.env.example / dart-define

### EXECUTION PROTOCOL FOR "asd"
1. cd ~/Berkahtigaputeri && git fetch --prune && git checkout main && git pull
2. Read DOC_00_ASD_MISSION.md + DOC_08_AUDIT_18_ISSUES.md + DOC_07
3. Pick first unchecked [ ] from P0 -> P1 -> P2 -> P3
4. Fix CODE + DOCS + WORKFLOW together (systemic)
5. Update this file [x] + add log below with new SHA
6. Commit + push to main via PR admin merge
7. Verify gh run list --branch main 7/7 green
8. LOOP until all [x]

### STATE LOG
- 2026-10-05 00:22Z main@68826ec audit 18 issues, 27->17 branches cleaned, CI green
- 2026-10-05 P0 mission doc created - next: P0-1 auth

### DONE CRITERIA
All [ ] -> [x], fresh DB rebuild passes, fresh APK auth->config, Admin toggle == APK, DOC_07 recertified, CI 7/7 green.
