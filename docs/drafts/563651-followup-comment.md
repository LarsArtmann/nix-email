Re-checked after #566282: still present, just renamed. With `provision.opensearch = false` (the default) the module still renders a host-less `[opensearch]` section — `opensearch.ssl` (bool, `false`) and `opensearch.cert_path` (path, `config.security.pki.caBundle`) are unconditionally non-empty and survive `filterAttrsRecursive`, while `hosts` (`[]` → `null` via `apply`) gets filtered out. parsedmarc now refuses with the opensearch-worded variant:

```
ConfigurationError: hosts setting missing from the opensearch config section
```

Verified against master today (module @ cbedd350, cli.py @ c7a9d294) and live on NixOS `fe132422` with parsedmarc 11.0.2 — unit exits 255 at start until the section is stripped. The two fixes from the report carry over unchanged: default `ssl`/`cert_path` to `null` behind `mkIf cfg.provision.opensearch`, or drop the whole `[opensearch]` section in `filteredConfig` when it is not provisioned and `hosts` is empty.
