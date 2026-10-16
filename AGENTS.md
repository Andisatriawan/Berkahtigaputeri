# Personal repository routing instructions

This repository is a historical personal copy, **not the canonical source of truth**.

- Canonical repository: https://github.com/berkah-pos/Berkahtigaputeri
- Canonical agent instructions: https://github.com/berkah-pos/Berkahtigaputeri/blob/main/AGENTS.md
- Accepted platform/engine/stack decision: https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/ADR-2026-10-16-OWNER-ARCHITECTURE-DECISION.md
- Canonical configuration contract: https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_00_CANONICAL_ARCHITECTURE_DECISION.md
- Target architecture and acceptance gates: https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_14_KVM2_ISOLATED_TENANT_ARCHITECTURE.md
- Canonical roadmap: https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_00_MASTER_ROADMAP.md

Do not follow local Supabase-specific directions in this historical copy as current architecture authority. The accepted target is Laravel Central API + PostgreSQL 17, but target selection does not mean it is implemented on canonical `main` or deployed. The canonical organization repository currently records a Supabase-backed Flutter runtime and keeps Supabase code/SQL/data as source/migration evidence until verified, owner-approved cutover.

New product, application, architecture, CI or deployment work belongs in the canonical organization repository on a dedicated branch and reviewed PR. Only change this personal repository when explicitly tasked with maintaining its redirect/history. Never rewrite old evidence to manufacture a pass; check exact candidate SHA, CI, staging observations and production evidence separately.
