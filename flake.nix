{
  description = "gloat's NixOS machines: g814 (ROG Strix G18 laptop), x3d (the PC) and web (the public VPS)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Only for packages that must track upstream faster than the stable branch.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Weekly prebuilt nix-index database (for comma and command-not-found). Building it locally doesn't work:
    # nix-index 0.1.10 can't read cache.nixos.org's zstd-compressed file listings and ends up nearly empty.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Secrets as age files in secrets/ (rules: secrets/secrets.nix), decrypted at activation into /run/agenix.
    # The module (web) and the `agenix` CLI (g814, x3d), which encrypts and edits them.
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # void's project (~/gloating): web's OpenResty takes the account code (acct/: Lua + its locations) from here,
    # so it keeps one home. After a change there: nix flake update gloating, then deploy web.
    gloating = {
      url = "git+ssh://vps-git/home/git/gloating.git";
      flake = false;
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, disko, home-manager, nix-index-database, agenix, gloating, ... }:
    let
      user = "gloat";
      # Every host: the unstable overlay, plus its own system modules; home-manager only where sessions run (home).
      mkHost = { modules, home ? null }: nixpkgs.lib.nixosSystem {
        specialArgs = { inherit user agenix gloating; };
        modules = [
          {
            # herdr (agent multiplexer) isn't packaged in stable at all.
            # llama-cpp-vulkan: 26.05's b9190 is too old for Gemma 4 (home/llm, x3d).
            nixpkgs.overlays = [
              (final: prev:
                let
                  unstable = import nixpkgs-unstable {
                    inherit (prev.stdenv.hostPlatform) system;
                    config.allowUnfree = true;
                  };
                in {
                  inherit (unstable) herdr llama-cpp-vulkan;
                })
            ];
          }
        ] ++ nixpkgs.lib.optionals (home != null) [
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              # niri's first-run config.kdl already exists; keep it as a backup instead of failing.
              backupFileExtension = "hm-bak";
              sharedModules = [ nix-index-database.homeModules.nix-index ];
              users.${user} = import home;
            };
          }
        ] ++ modules;
      };
    in {
      nixosConfigurations.g814 = mkHost {
        modules = [ disko.nixosModules.disko ./hosts/g814 ];
        home = ./home;
      };
      nixosConfigurations.x3d = mkHost {
        modules = [ disko.nixosModules.disko ./hosts/x3d ];
        home = ./home/x3d.nix;
      };
      # Services only, no sessions: no home-manager (handoff vps-to-all-2026-10-26-1406-gitops-workflow).
      nixosConfigurations.web = mkHost {
        modules = [ disko.nixosModules.disko agenix.nixosModules.default ./hosts/web ];
      };
    };
}
