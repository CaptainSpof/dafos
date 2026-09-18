# devenv templates

Each directory here is a flake template (Snowfall exports it as
`templates.<dir>`; descriptions live in `flake.nix`). `devinit <name>` (direnv
module) runs `nix flake init -t self#<name>`, appends devenv's ignores to
`.gitignore` and runs `direnv allow`.

- A template is copied verbatim into someone else's project: keep it
  self-contained — no reference to dafos paths, `lib.dafos` or this flake's
  inputs, and nothing here but files the project should own.
- Never ship a `.gitignore`: `nix flake init` refuses to overwrite one, and most
  toolchains write their own. `devinit` appends the entries instead.
- Native devenv (`devenv.yaml` + `use devenv`), not the flake integration: it
  keeps the eval cache, `devenv up`/tasks/containers, and needs no `--impure`.
- Only enable toolchain hooks that work in an empty directory (`uv sync`,
  `pnpm install` fail without a manifest); leave those commented.
- A new or changed template gets built before commit: copy it to a scratch dir
  and `devenv shell -- <tool> --version`.
- `self#` resolves to the last switched revision — test with
  `nix flake init -t .#<name>` from the repo before switching.
