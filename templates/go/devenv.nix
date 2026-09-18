_:

{
  # Also brings gopls and delve.
  languages.go.enable = true;

  # With a C compiler on PATH Go links cgo against the store's glibc, and the
  # binary then fails to start in any container ("no such file or directory"
  # on the loader). Static by default; `CGO_ENABLED=1 go build` when needed.
  env.CGO_ENABLED = "0";
}
