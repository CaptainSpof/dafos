# Custom library

Helpers are exported as `lib.dafos.*` (and reachable as `lib.<name>` where
flattened). Add one for demonstrated reuse or shared pure logic; keep one-off,
module-specific logic with the module that needs it.

## Namespaces

- `module` — [module/default.nix](module/default.nix): `mkOpt`, `mkBoolOpt`, and
  the `enabled` / `disabled` shortcuts (`{ enable = true; }` / `false`).
- `deploy` — [deploy/default.nix](deploy/default.nix): `mkDeploy`, the deploy-rs
  wiring. It respects `dafos.security.doas.enable` and switches to `doas -u`
  when that is set.

Do not mirror the full function inventory here; the source owns it.

## Usage

```nix
let
  inherit (lib.dafos) enabled mkOpt;
in
{
  dafos.suites.desktop = enabled;
}
```
