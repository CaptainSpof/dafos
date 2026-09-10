# podman

## Container DNS is firewalled by default

The NixOS firewall silently drops container→aardvark-dns traffic on custom
podman networks. The symptom is inside the container, not in any host log:

```
dial tcp: lookup <host> on 10.89.x.1:53: i/o timeout
```

[default.nix](default.nix) opens TCP and UDP 53 on `podman+` interfaces
fleet-wide. It is keyed on the upstream `virtualisation.podman.enable`, not on
the `dafos` option, because oci-container service modules turn podman on without
going through the wrapper.

**Rootless containers are unaffected** — their networking lives in a user
namespace. When a stack in `modules/home/services` cannot resolve a name, this
is not the cause.

## Rootless subuid range

`autoSubUidGidRange` is set for the primary user. Without `/etc/subuid` and
`/etc/subgid` the namespace maps exactly one id, every file owned by anyone else
is stored as 65534, and crun fails with `fchownat: Invalid argument` as soon as
a container reproduces that ownership.
