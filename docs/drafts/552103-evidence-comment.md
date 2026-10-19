Vendored this PR's module to run it against 0.16.22 before it lands (NixOS VM tests, pin 6774f7bc; https://github.com/LarsArtmann/nix-email). Two behaviors the provisioning side has to work around, in case they are not on your radar:

`stalwart-cli apply` succeeds against a running server, but NetworkListener objects only take effect after a process restart. We apply, then `systemctl try-restart stalwart`, then wait for the configured port - without the restart the process keeps serving on whatever it booted with.

On a virgin store the server binds only the built-in default set (smtp 25 + http 127.0.0.1:8080), no matter what httpBind the config declares. A provision step that probes only its own configured URL deadlocks there (hit it as https://github.com/LarsArtmann/nix-email/issues/4); probing the configured URL first and falling back to 127.0.0.1:8080 unblocks every shape.
