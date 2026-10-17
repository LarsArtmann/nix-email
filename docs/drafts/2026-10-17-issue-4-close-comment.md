Landed: the provision unit probes cfg.url, falls back to the built-in 127.0.0.1:8080, applies against whichever answered, restarts stalwart, then verifies the configured bind comes up - so "listeners never activated" now fails the unit instead of passing silently (modules/stalwart-module/provision.nix, applyScript/restartAndVerify).

stalwart-bind-e2e pins the dedicated-port case (virgin store, httpBind 127.0.0.1:8082, the exact shape from the pbx burn; first run caught a multi-line ExecStart quoting trap, second green):

```
stalwart-provision: management API answering at http://127.0.0.1:8080 (configured: http://127.0.0.1:8082)
```

The inert static render was already gone at HEAD - the remaining asks were the fallback design and the coverage, both in.
