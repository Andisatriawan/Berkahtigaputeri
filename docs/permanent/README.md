# Historical documentation index — personal mirror only

> **Canonical documentation:** [berkah-pos/Berkahtigaputeri/docs/permanent](https://github.com/berkah-pos/Berkahtigaputeri/tree/main/docs/permanent)  
> **Canonical agent contract:** [AGENTS.md](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/AGENTS.md)  
> **Accepted platform/engine/stack decision:** [Owner ADR — Laravel Central API + PostgreSQL 17](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/ADR-2026-10-16-OWNER-ARCHITECTURE-DECISION.md)  
> **Current target details and gates:** [DOC_14](https://github.com/berkah-pos/Berkahtigaputeri/blob/main/docs/permanent/DOC_14_KVM2_ISOLATED_TENANT_ARCHITECTURE.md)

This index belongs to a personal legacy snapshot and is **not the current architecture authority**. The files below remain for historical reference, configuration-contract provenance and migration investigation only. Their Supabase-specific schema, RLS, RPC and operating guidance must not be treated as the accepted future runtime instructions.

## Correct status boundary

The accepted owner ADR selects Laravel Central API + PostgreSQL 17, but an ADR does not prove implementation or deployment. At the organization main baseline d7ee23cfaada3405416b01d9e127e32b07fb1a38, Flutter was still Supabase-backed and root Composer files were absent. Consult the live organization repository for the latest source, open PRs, exact-SHA CI, staging observations and production acceptance evidence.

The five-layer configuration contract remains:

```text
GLOBAL → TEMPLATE → TENANT → SERVICE → DEVICE
```

The organization DOC_00 owns the workbook and configuration contract; the merged owner ADR owns platform/engine/stack; canonical DOC_14 is subordinate target detail; the organization master roadmap owns phase numbering. Read those documents in the canonical repository.

## Preservation rule

Legacy Supabase SQL/schema/RLS/RPC, scripts, workbook-validation history and reports are retained as historical/migration inputs. Do not delete them blindly or execute mutation-capable scripts against an unknown/shared resource. Migration, source-of-truth identification and production deployment/acceptance remain **BLOCKED** or **NOT RUN / NOT VERIFIED** until supported by current direct evidence and owner approval.
