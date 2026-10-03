# Copilot Instructions - Berkah POS SaaS

This repo uses 3-layer config compliance. Before any code change, read:

- docs/permanent/DOC_00_MASTER_ROADMAP.md
- docs/permanent/DOC_01_3_LAYER_CONFIG.md
- docs/permanent/DOC_02_SUPABASE_SCHEMA_V1.sql

Rules:
- app_config table is key PRIMARY KEY, value JSONB - NOT (device_id, key, value)
- Keys: 'global', 'tenant:<id>', 'tenant:<id>:service:pos', 'tenant:<id>:service:akuntansi', 'device:<id>'
- Official admin: btp-admin/index.html (redirect), btp-admin/clients.html, btp-admin/edit.html
- Never create duplicate complete-settings.html
- HEAD CORE a19cb3f must not be broken
- All docs in docs/permanent/ are accumulated permanently, never delete
- Check live URL: https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/
