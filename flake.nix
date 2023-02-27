{
  description = "Flake that configures Xremap, a key remapper for Linux";

  inputs = {
    # Nixpkgs will be pinned to unstable to get the latest Rust
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Flake utilities
    flake-utils.url = "github:numtide/flake-utils";
    # Utils for building Rust stuff
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # The Rust source for xremap
    xremap-src = {
      url = "github:k0kubun/xremap?ref=v0.8.2";
      flake = false;
    };
    hyprland = {
      url = "github:hyprwm/Hyprland";
    };
  };
  outputs = { self, nixpkgs, crane, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        craneLib = crane.lib.${system};
        xremap = craneLib.buildPackage {
          src = inputs.xremap-src;
        };
      in
      {
        checks = {
          inherit xremap;
        };

        packages.default = xremap;

        apps.default = flake-utils.lib.mkApp {
          drv = xremap;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = builtins.attrValues self.checks.${system};
          nativeBuildInputs = with pkgs; [
            cargo
            rustc
            rustfmt
          ];
        };

      # See comments in the module
      nixosModules.default = import ./modules xremap;
      
      nixosConfigurations =
        let
          default_modules = [
            self.nixosModules.default
            ./nixosConfigurations/vm-config.nix
            {
              services.xremap = {
                userName = "alice";
                config = {
                  keymap = [
                    {
                      name = "Test remap a>b in kitty";
                      application = {
                        "only" = "kitty";
                      };
                      remap = {
                        "a" = "b";
                      };
                    }
                    {
                      name = "Test remap c>d everywhere";
                      remap = {
                        "x" = "z";
                      };
                    }
                  ];
                };
              };
            }
          ];
          system = "x86_64-linux";
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          hyprland-system-dev = nixpkgs.lib.nixosSystem {
            inherit pkgs system;
            modules = [
              hyprland.nixosModules.default
              {
                boot.tmpOnTmpfs = true; # To clean out hyprland socket
                networking.hostName = "hyprland-system-dev";
                programs.hyprland = {
                  enable = true;
                };
                services.xremap = {
                  withHypr = true;
                };
              }
            ] ++ default_modules;
          };
          hyprland-user-dev = nixpkgs.lib.nixosSystem {
            inherit pkgs system;
            modules = [
              hyprland.nixosModules.default
              {
                boot.tmpOnTmpfs = true; # To clean out hyprland socket
                networking.hostName = "hyprland-user-dev";
                programs.hyprland = {
                  enable = true;
                };
                services.xremap = {
                  withHypr = true;
                  serviceMode = "user";
                };
              }
            ] ++ default_modules;
          };
          # NOTE: after alice is logged in - need to run systemctl restart xremap.service to pick up the socket
          sway-system-dev = nixpkgs.lib.nixosSystem {
            inherit pkgs system;
            modules = [
              {
                programs.sway.enable = true;
              }
              ./nixosConfigurations/sway-common.nix
            ] ++ default_modules;
          };
        };
    });
}
