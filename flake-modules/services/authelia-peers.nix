# Authelia and lldap run on dafoltop only, but an nps app registers its OIDC
# client, authorization/claims policies and lldap group in the authelia and
# lldap stacks *of the home it runs in*. For an app on another host (dafpi)
# those land in a stack that is not running there. This aspect, on the host
# that runs Authelia, reads them from each peer's configuration and adds them
# here, so moving an app needs no hand-copied client.
#
# A client whose secret is hashed at start (`toHash`, the nps default) points
# at a sops secret file in the peer's home; the same secret is declared here
# under the same name, so it lands at the same path. Its sops file therefore
# has to be readable by both hosts (.sops.yaml).
{ inputs, ... }:
{
  flake.modules.homeManager.authelia-peers =
    { config, lib, ... }:
    let
      inherit (lib) mkIf mkOption types;

      cfg = config.dafos.services.authelia-peers;

      peerHome = peer: inputs.self.nixosConfigurations.${peer}.config.home-manager.users.daf;
      collect = f: lib.foldl' (acc: peer: acc // f (peerHome peer)) { } cfg.peers;
      nonEmpty = attrs: mkIf (attrs != { }) attrs;

      oidcSettings = h: h.nps.stacks.authelia.settings.identity_providers.oidc or { };

      clients = collect (h: h.nps.stacks.authelia.oidc.clients);

      hashedSecretPaths = lib.concatMap (
        c:
        lib.optional (
          lib.isAttrs c.client_secret && (c.client_secret.toHash or null) != null
        ) c.client_secret.toHash
      ) (lib.attrValues clients);

      peerSecrets = collect (
        h: lib.filterAttrs (_: s: builtins.elem s.path hashedSecretPaths) h.sops.secrets
      );
    in
    {
      options.dafos.services.authelia-peers.peers = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "dafpi" ];
        description = "Hosts whose apps' OIDC clients, policies and lldap groups this host's Authelia/lldap serve.";
      };

      config = mkIf (cfg.peers != [ ]) {
        nps.stacks.authelia.oidc.clients = nonEmpty clients;

        nps.stacks.authelia.settings.identity_providers.oidc = {
          authorization_policies = nonEmpty (collect (h: (oidcSettings h).authorization_policies or { }));
          claims_policies = nonEmpty (collect (h: (oidcSettings h).claims_policies or { }));
        };

        nps.stacks.lldap.bootstrap.groups = nonEmpty (collect (h: h.nps.stacks.lldap.bootstrap.groups));

        sops.secrets = nonEmpty (
          lib.mapAttrs (_: s: {
            inherit (s) sopsFile key format;
          }) peerSecrets
        );
      };
    };
}
