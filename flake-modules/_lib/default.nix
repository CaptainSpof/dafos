# Snowfall Lib + flake-utils-plus compatibility layer.
#
# Phase 1 of the flake-parts migration: this file reproduces, explicitly, what
# snowfall-lib's mkFlake used to assemble implicitly — channel instantiation,
# the `${namespace}`/`lib.dafos` specialArgs, the module wrapper, and the
# home-manager embedding — so the existing modules/, systems/, homes/,
# packages/, overlays/, lib/, shells/ and checks/ trees keep evaluating
# unchanged. It is meant to shrink and eventually disappear as the tree is
# migrated to dendritic flake-parts modules.
#
# Faithfulness notes (verified against snowfall-lib and flake-utils-plus
# sources; see git history of the migration for the exact revisions):
#   - module import order is preserved (it affects list-option merge order),
#   - each channel = import <input> { config = channels-config; overlays },
#     with the dafos package overlay + flake overlays + overlays/ applied to
#     the `nixpkgs` channel only,
#   - modules/{nixos,home} files are wrapped to receive the same modified
#     args (lib with `dafos`/`snowfall`, channel pkgs, inputs, namespace,
#     format/target/virtual) snowfall passed them,
#   - the FUP host module (hostname, nixpkgs.pkgs, registry options,
#     nix.package/extraOptions defaults) and snowfallorg user modules are
#     vendored under ../_compat.
{
  inputs,
  systems,
  # Dendritic aspects standing in for deleted legacy modules, keyed by the
  # legacy path relative to modules/{nixos,home} (e.g. "services/openssh").
  # The key keeps the aspect at the legacy module's place in the import
  # order, so list-option merge order — and the nix-diff gate — is unchanged.
  migrated ? { },
}:
let
  lib0 = inputs.nixpkgs.lib;

  inherit (builtins)
    baseNameOf
    dirOf
    readDir
    pathExists
    ;
  inherit (lib0)
    filterAttrs
    flatten
    foldl
    hasInfix
    hasSuffix
    isFunction
    isDerivation
    last
    listToAttrs
    mapAttrs
    mapAttrsToList
    mkDefault
    mkIf
    nameValuePair
    optionals
    removePrefix
    splitString
    ;

  namespace = "dafos";
  src = ../..;

  # `inputs` includes `self` (flake.nix hands the whole outputs argument
  # through) — snowfall's specialArg `inputs` did too.
  user-inputs = inputs;
  inputs-no-self = builtins.removeAttrs inputs [ "self" ];

  # ------------------------------------------------------------------
  # channels-config (was the `channels-config` argument to mkFlake)
  # ------------------------------------------------------------------
  channels-config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      # "aspnetcore-runtime-6.0.36"
      # "emacs-unstable-pgtk-30.1"
      # "emacs-unstable-pgtk-with-packages-30.1"
      # "dotnet-sdk-6.0.428"
      # "qtwebengine-5.15.19"
      # "olm-3.2.16"
      # discontinued upstream in favour of Vortex (Windows-only); still
      # installs Cyberpunk collections natively
      "nexusmods-app-unfree-0.21.1"
    ];
  };

  # ------------------------------------------------------------------
  # filesystem helpers (snowfall-lib fs.*, same traversal order:
  # readDir attr order = lexicographic, directories recursed in place)
  # ------------------------------------------------------------------
  safe-read-directory = path: if pathExists path then readDir path else { };

  get-files =
    path:
    mapAttrsToList (name: _: "${path}/${name}") (
      filterAttrs (_: kind: kind == "regular") (safe-read-directory path)
    );

  get-files-recursive =
    path:
    flatten (
      mapAttrsToList (
        name: kind:
        let
          path' = "${path}/${name}";
        in
        if kind == "directory" then get-files-recursive path' else path'
      ) (filterAttrs (_: kind: kind == "regular" || kind == "directory") (safe-read-directory path))
    );

  get-default-nix-files-recursive =
    path: builtins.filter (p: baseNameOf p == "default.nix") (get-files-recursive path);

  get-nix-files = path: builtins.filter (p: hasSuffix ".nix" p) (get-files path);

  get-non-default-nix-files =
    path: builtins.filter (p: hasSuffix ".nix" p && baseNameOf p != "default.nix") (get-files path);

  get-non-default-nix-files-recursive =
    path:
    builtins.filter (p: hasSuffix ".nix" p && baseNameOf p != "default.nix") (get-files-recursive path);

  get-file = path: "${src}/${path}";

  get-directories =
    path:
    mapAttrsToList (name: _: "${path}/${name}") (
      filterAttrs (_: kind: kind == "directory") (safe-read-directory path)
    );

  # The subset of `lib.snowfall` the tree actually uses (sops sopsFile paths
  # via fs.get-file, firefox's fs.get-non-default-nix-files). Extend here if
  # eval turns up another consumer.
  snowfall-compat = {
    path =
      let
        file-name-regex = "(.*)\\.(.*)$";
        has-any-file-extension = file: (builtins.match file-name-regex (toString file)) != null;
        get-file-extension =
          file:
          if has-any-file-extension file then last (builtins.match file-name-regex (toString file)) else "";
      in
      {
        inherit has-any-file-extension get-file-extension;

        has-file-extension =
          extension: file: has-any-file-extension file && extension == get-file-extension file;

        get-parent-directory = p: baseNameOf (dirOf p);

        get-file-name-without-extension =
          path:
          let
            file-name = baseNameOf path;
            match = builtins.match file-name-regex file-name;
          in
          if match != null then builtins.head match else file-name;
      };

    fs = {
      inherit
        get-file
        get-files
        get-files-recursive
        get-directories
        get-nix-files
        get-default-nix-files-recursive
        get-non-default-nix-files
        get-non-default-nix-files-recursive
        ;
    };
  };

  # ------------------------------------------------------------------
  # lib: system-lib / user-lib / home-lib (snowfall internal/default.nix)
  # ------------------------------------------------------------------
  # snowfall merged every input's `lib` attribute into the top level of lib
  # (lib.home-manager, lib.deploy-rs, ...). lib.home-manager.hm is load-bearing
  # for home-lib below.
  input-libs = mapAttrs (_: i: i.lib) (
    filterAttrs (_: i: builtins.isAttrs (i.lib or null)) inputs-no-self
  );

  mk-lib =
    dafos:
    lib0
    // input-libs
    // {
      snowfall = snowfall-compat;
      ${namespace} = dafos;
    };

  user-lib = lib0.fix (
    ul:
    let
      call-args = {
        inputs = inputs-no-self;
        snowfall-inputs = { inherit (inputs) nixpkgs; };
        inherit namespace;
        lib = mk-lib ul;
      };
      import-lib =
        path:
        let
          imported = import path;
        in
        if isFunction imported then lib0.callPackageWith call-args path { } else imported;
    in
    foldl lib0.recursiveUpdate { } (map import-lib (get-default-nix-files-recursive (src + "/lib")))
  );

  system-lib = mk-lib user-lib;

  # Built with lib.extend (not a plain merge) — home-manager's docs machinery
  # calls `.extend` on this lib, and only an extend-chained lib keeps the
  # `hm`/`dafos` layers through further extensions (snowfall's home-lib
  # expression, kept verbatim).
  home-lib = lib0.extend (
    _final: prev:
    system-lib
    // prev
    // {
      hm = system-lib.home-manager.hm;
    }
  );

  # ------------------------------------------------------------------
  # virtual system targets (snowfall system.get-virtual-system-type)
  # ------------------------------------------------------------------
  virtual-type =
    target:
    let
      suffix = last (splitString "-" target);
    in
    if suffix == "linux" || suffix == "darwin" then "" else suffix;

  resolve-system =
    target:
    let
      vt = virtual-type target;
    in
    if vt == "" then target else builtins.replaceStrings [ vt ] [ "linux" ] target;

  # ------------------------------------------------------------------
  # channels (FUP importChannel): every input that looks like a nixpkgs
  # (legacyPackages.<sys>.nix) becomes a channel; only `nixpkgs` gets the
  # dafos package overlay + flake overlays + overlays/.
  # ------------------------------------------------------------------
  channel-inputs = filterAttrs (_: v: (v.legacyPackages.x86_64-linux or { }) ? nix) inputs-no-self;

  # non-flake inputs, exposed as pkgs.srcs by FUP
  srcs = filterAttrs (_: v: !(v ? outputs)) inputs;

  srcs-overlay = _final: _prev: {
    __dontExport = true;
    inherit srcs;
  };

  # FUP appended its own overlay providing fup-repl (the common home suite
  # enables a wrapper around it, so it stays vendored).
  fup-overlay = final: _prev: {
    __dontExport = true;
    fup-repl = final.callPackage ../_compat/fup-repl.nix { };
  };

  # the `overlays = with inputs; [ ... ]` list from the old flake.nix
  extra-overlays = with inputs; [
    claude-desktop.overlays.default
    emacs-overlay.overlays.default
    niri.overlays.niri
    nix-firefox-addons.overlays.default
  ];

  user-overlay-files = get-default-nix-files-recursive (src + "/overlays");

  mk-user-overlay =
    channels: file:
    import file (
      # Deprecated (kept from snowfall): overlay files may also reference
      # input names directly.
      user-inputs
      // {
        inherit channels;
        inputs = user-inputs;
        lib = system-lib;
      }
    );

  packages-overlay = channels: final: prev: {
    ${namespace} =
      (prev.${namespace} or { })
      // (create-packages {
        pkgs = final;
        inherit channels;
      });
  };

  overlays-builder =
    channels:
    [ (packages-overlay channels) ]
    ++ extra-overlays
    ++ (map (mk-user-overlay channels) user-overlay-files);

  mk-channels =
    system:
    lib0.fix (
      channels:
      mapAttrs (
        name: input:
        (import input {
          inherit system;
          overlays = [
            srcs-overlay
          ]
          ++ (optionals (name == "nixpkgs") (overlays-builder channels))
          ++ [ fup-overlay ];
          config = channels-config;
        })
        // {
          inherit name input;
        }
      ) channel-inputs
    );

  channels-by-system = lib0.genAttrs systems mk-channels;

  # ------------------------------------------------------------------
  # packages/ (snowfall package.create-packages)
  # ------------------------------------------------------------------
  package-files = get-default-nix-files-recursive (src + "/packages");

  create-packages =
    { pkgs, channels }:
    let
      pkg-set = foldl (
        acc: file:
        acc
        // {
          ${builtins.unsafeDiscardStringContext (baseNameOf (dirOf file))} =
            let
              extra-inputs =
                pkgs
                // {
                  ${namespace} = pkg-set;
                }
                // {
                  inherit channels namespace;
                  lib = system-lib;
                  pkgs = pkgs // {
                    ${namespace} = pkg-set;
                  };
                  inputs = user-inputs;
                };
              pkg = lib0.callPackageWith extra-inputs file { };
            in
            pkg
            // {
              meta = (pkg.meta or { }) // {
                snowfall.path = file;
              };
            };
        }
      ) { } package-files;
    in
    pkg-set;

  # ------------------------------------------------------------------
  # module wrapper (snowfall module.create-modules): every file under
  # modules/{nixos,home} gets snowfall's modified args.
  # ------------------------------------------------------------------
  wrap-module =
    file: args:
    let
      system = args.system or args.pkgs.stdenv.hostPlatform.system;
      target = args.target or system;
      vt = virtual-type target;
      format =
        if vt != "" then
          vt
        else if hasInfix "darwin" target then
          "darwin"
        else
          "linux";

      modified-args = args // {
        inherit system target format;
        virtual = args.virtual or (vt != "");
        systems = args.systems or { };

        lib = system-lib;
        pkgs = channels-by-system.${system}.nixpkgs;

        inputs = user-inputs;
        inherit namespace;
      };
      imported = import file;
      user-module = if isFunction imported then imported modified-args else imported;
    in
    user-module // { _file = file; };

  # attrset keyed by path relative to the modules root — attrNames sorting
  # reproduces snowfall's module order (it affects list-option merge order).
  wrapped-modules-attrs =
    root:
    listToAttrs (
      map (
        file:
        nameValuePair (builtins.unsafeDiscardStringContext (
          removePrefix "/" (builtins.replaceStrings [ "${root}" "/default.nix" ] [ "" "" ] file)
        )) (wrap-module file)
      ) (get-default-nix-files-recursive root)
    );

  # A `flake.modules.<class>.<name>` value is three import levels deep
  # (flake-parts' class wrapper -> deferredModule merge -> one entry per
  # definition). The module system collects imports breadth-first, so left
  # nested its definitions would land after every top-level module and
  # reorder list options. Unwrap it to the defining modules themselves.
  unwrap-aspect =
    aspect: flatten (map (merged: map (def: def.imports) merged.imports) (aspect { }).imports);

  with-migrated =
    class: legacy:
    let
      aspects = migrated.${class} or { };
      clashes = builtins.filter (key: legacy ? ${key}) (builtins.attrNames aspects);
    in
    if clashes != [ ] then
      throw "dafos compat: ${class} module(s) ${toString clashes} exist both as legacy modules and as migrated aspects; delete the legacy copy"
    else
      mapAttrs (_: m: [ m ]) legacy // mapAttrs (_: unwrap-aspect) aspects;

  wrapped-nixos-modules = flatten (
    mapAttrsToList (_: ms: ms) (with-migrated "nixos" (wrapped-modules-attrs (src + "/modules/nixos")))
  );
  wrapped-home-modules-attrs = with-migrated "home" (wrapped-modules-attrs (src + "/modules/home"));

  # ------------------------------------------------------------------
  # home-manager embedding (snowfall home.create-home-system-modules)
  # ------------------------------------------------------------------
  # the `homes.modules` list from the old flake.nix
  home-shared-input-modules = with inputs; [
    nix-podman-stacks.homeModules.nps
    nix-index-database.homeModules.nix-index
    plasma-manager.homeModules.plasma-manager
    sops-nix.homeManagerModules.sops
    zen-browser.homeModules.beta
    niri.homeModules.niri
    vicinae.homeManagerModules.default
    dank-material-shell.homeModules.dank-material-shell
    dank-material-shell.homeModules.niri
    dank-calendar.homeModules.dank-calendar
    dms-proofreader.homeModules.default
  ];

  # homes/<system>/<user>@<host>
  home-entries = flatten (
    mapAttrsToList (
      sys-name: sys-kind:
      if sys-kind != "directory" then
        [ ]
      else
        mapAttrsToList (
          home-name: _:
          let
            name-parts = builtins.filter builtins.isString (builtins.split "@" home-name);
          in
          {
            name = home-name;
            user = builtins.elemAt name-parts 0;
            host = if builtins.length name-parts > 1 then builtins.elemAt name-parts 1 else "";
            system = sys-name;
            path = src + "/homes/${sys-name}/${home-name}/default.nix";
          }
        ) (filterAttrs (_: kind: kind == "directory") (safe-read-directory (src + "/homes/${sys-name}")))
    ) (safe-read-directory (src + "/homes"))
  );

  extra-special-args-module =
    {
      pkgs,
      system ? pkgs.stdenv.hostPlatform.system,
      target ? system,
      format ? "home",
      host ? "",
      virtual ? ((virtual-type target) != ""),
      systems ? { },
      ...
    }:
    {
      _file = "virtual:snowfallorg/home/extra-special-args";

      config = {
        home-manager.extraSpecialArgs = {
          inherit
            system
            target
            format
            virtual
            systems
            host
            ;

          lib = home-lib;

          inputs = user-inputs;
        };
      };
    };

  snowfall-user-home-module = {
    _file = "virtual:snowfallorg/modules/home/user/default.nix";

    config = {
      home-manager.sharedModules = [ ../_compat/snowfallorg-user-home.nix ];
    };
  };

  shared-user-modules = mapAttrsToList (module-path: modules: {
    _file = "${toString src}/modules/home/${module-path}/default.nix";

    config = {
      home-manager.sharedModules = modules;
    };
  }) wrapped-home-modules-attrs;

  mk-home-system-module =
    home:
    {
      config,
      options,
      pkgs,
      host ? "",
      system ? pkgs.stdenv.hostPlatform.system,
      ...
    }:
    let
      host-matches = (home.host == host) || (home.host == "" && home.system == system);

      # Remap definitions of `snowfallorg.users.<name>.home.config` into the
      # actual home-manager user configuration (snowfall's mechanism, kept
      # verbatim so definition priorities behave identically).
      wrap-user-options =
        user-option:
        if (user-option ? "_type") && user-option._type == "merge" then
          user-option
          // {
            contents = builtins.map (
              merge-entry: merge-entry.${home.user}.home.config or { }
            ) user-option.contents;
          }
        else
          user-option;

      home-config = lib0.mkAliasAndWrapDefinitions wrap-user-options options.snowfallorg.users;
    in
    {
      _file = "virtual:snowfallorg/home/user/${home.name}";

      config = mkIf host-matches {
        snowfallorg.users.${home.user}.home.config = {
          snowfallorg.user = {
            enable = mkDefault true;
            name = mkDefault home.user;
          };

          # NOTE: specialArgs are not propagated by home-manager without this.
          _module.args = {
            inherit namespace;
          };
        };

        home-manager = {
          users.${home.user} = mkIf config.snowfallorg.users.${home.user}.home.enable (
            { ... }:
            {
              imports = (home-config.imports or [ ]) ++ [ home.path ];
              config = builtins.removeAttrs home-config [ "imports" ];
            }
          );

          # Without this home-manager would create its own package set,
          # missing the flake's channel config and overlays.
          useGlobalPkgs = mkDefault true;
        };
      };
    };

  home-system-modules = [
    extra-special-args-module
    snowfall-user-home-module
  ]
  ++ (map (m: { config.home-manager.sharedModules = [ m ]; }) home-shared-input-modules)
  ++ shared-user-modules
  ++ (map mk-home-system-module home-entries);

  # ------------------------------------------------------------------
  # NixOS system assembly (FUP configurationBuilder + snowfall create-system)
  # ------------------------------------------------------------------
  # the `systems.modules.nixos` list from the old flake.nix
  system-input-modules = with inputs; [
    disko.nixosModules.disko
    home-manager.nixosModules.home-manager
    nix-gaming.nixosModules.platformOptimizations
    sops-nix.nixosModules.sops
    vault-service.nixosModules.nixos-vault-service
  ];

  # FUP's inline host module (hostname, channel pkgs, nix defaults).
  fup-host-module =
    { name, channels }:
    {
      pkgs,
      lib,
      ...
    }:
    lib.mkMerge [
      { networking.hostName = name; }
      { networking.domain = lib.mkDefault null; }
      {
        # no module in the tree sets nixpkgs.config, so the channel can be
        # used as-is (FUP pre-evaluated the config to check this; we assert
        # the simpler invariant statically).
        nixpkgs.pkgs = channels.nixpkgs;
        nixpkgs.config = lib.mkForce { };
      }
      { system.configurationRevision = lib.mkIf (inputs.self ? rev) (inputs.self.rev or ""); }
      { nix.package = lib.mkDefault pkgs.nixVersions.latest; }
      { nix.extraOptions = "extra-experimental-features = nix-command flakes"; }
      {
        _module.args = {
          inputs = user-inputs;
        };
      }
    ];

  mk-special-args =
    {
      name,
      target,
      system,
      format,
      channels,
    }:
    (listToAttrs (
      mapAttrsToList (
        channel-name: channel:
        nameValuePair "${channel-name}ModulesPath" (toString (channel.input + "/nixos/modules"))
      ) channels
    ))
    // {
      modulesPath = toString (channels.nixpkgs.path + "/nixos/modules");
      channel = channels.nixpkgs;

      inherit target system format;
      systems = { };
      lib = system-lib;
      host = name;

      virtual = (virtual-type target) != "";
      inputs = user-inputs;
      inherit namespace;
    };

  mk-modules =
    {
      name,
      target,
      channels,
    }:
    [
      (fup-host-module { inherit name channels; })
      (src + "/systems/${target}/${name}/default.nix")
    ]
    ++ wrapped-nixos-modules
    ++ system-input-modules
    ++ [ inputs.home-manager.nixosModules.home-manager ]
    ++ home-system-modules
    ++ [
      ../_compat/snowfallorg-users-nixos.nix
      ../_compat/fup-options.nix
    ];

  mk-host =
    { name, target }:
    let
      system = resolve-system target;
      channels = channels-by-system.${system};
    in
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      lib = channels.nixpkgs.lib;
      baseModules = import (channels.nixpkgs.path + "/nixos/modules/module-list.nix");
      specialArgs = mk-special-args {
        inherit
          name
          target
          system
          channels
          ;
        format = "linux";
      };
      modules = mk-modules { inherit name target channels; };
    };

  # systems/<target>/<host> — plain targets only: the virtual/ISO systems
  # (and nixos-generators) are gone from the tree.
  host-entries = flatten (
    mapAttrsToList (
      target: kind:
      if kind != "directory" then
        [ ]
      else
        mapAttrsToList (name: _: { inherit name target; }) (
          filterAttrs (
            name: k: k == "directory" && pathExists (src + "/systems/${target}/${name}/default.nix")
          ) (safe-read-directory (src + "/systems/${target}"))
        )
    ) (safe-read-directory (src + "/systems"))
  );

  configurations.nixosConfigurations = listToAttrs (
    map (host: nameValuePair host.name (mk-host host)) host-entries
  );

  # ------------------------------------------------------------------
  # shells/ and checks/ (snowfall shell.create-shells / check.create-checks)
  # ------------------------------------------------------------------
  call-dir =
    { dir, channels }:
    listToAttrs (
      map (
        file:
        nameValuePair (builtins.unsafeDiscardStringContext (baseNameOf (dirOf file))) (
          lib0.callPackageWith (
            channels.nixpkgs
            // {
              inherit channels namespace;
              lib = system-lib;
              inputs = user-inputs;
            }
          ) file { }
        )
      )
      # Path values, not the interpolated strings get-files returns: those copy
      # `dir` alone into the store, and a relative import such as
      # checks/pre-commit-hooks' `../../treefmt.nix` then resolves outside it.
      (builtins.filter (p: baseNameOf p == "default.nix") (lib0.filesystem.listFilesRecursive dir))
    );
in
{
  inherit
    namespace
    channels-by-system
    system-lib
    user-lib
    home-lib
    configurations
    create-packages
    ;

  per-system =
    system:
    let
      channels = channels-by-system.${system};
    in
    {
      packages = filterAttrs (_: isDerivation) (create-packages {
        pkgs = channels.nixpkgs;
        inherit channels;
      });

      devShells = call-dir {
        dir = src + "/shells";
        inherit channels;
      };

      checks = call-dir {
        dir = src + "/checks";
        inherit channels;
      };

      formatter = inputs.treefmt-nix.lib.mkWrapper channels.nixpkgs (src + "/treefmt.nix");
    };
}
