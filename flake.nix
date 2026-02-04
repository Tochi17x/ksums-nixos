{
  description = "KSUMS Universal NixOS Flake;

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    copyparty.url = "github:9001/copyparty";
    copyparty.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, copyparty, ... }:
  let
    lib = nixpkgs.lib;

    # Global: allow unfree everywhere
    unfreeModule = {
      nixpkgs.config.allowUnfree = true;
    };

    # Shared KSUMS module
    ksumsModule = { config, pkgs, ... }:
    let
      cfg = config.ksums;

      ksumsMumble = pkgs.writeScriptBin "ksums-mumble" ''
        #!${pkgs.python3}/bin/python3
        import os, sys, subprocess, time

        def is_headless():
            return not (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))

        server = os.environ.get("MUMBLE_HOST", cfg.pi)
        port = os.environ.get("MUMBLE_PORT", "64738")
        user = os.environ.get("MUMBLE_USER", cfg.user)

        headless = "--headless" in sys.argv or (is_headless() and "--gui" not in sys.argv)

        if headless:
            cmd = ["${pkgs.mum}/bin/mumd", "--server", f"{server}:{port}", "--username", user]
        else:
            cmd = ["${pkgs.mumble}/bin/mumble", f"mumble://{user}@{server}:{port}"]

        while True:
            try:
                if subprocess.run(cmd).returncode == 0:
                    break
            except KeyboardInterrupt:
                break
            except Exception:
                pass
            time.sleep(5)
      '';
    in {
      options.ksums = {
        role = lib.mkOption {
          type = lib.types.enum [ "laptop" "server" "vm" ];
          default = "laptop";
        };

        pi = lib.mkOption {
          type = lib.types.str;
          default = "192.168.1.50";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "Crew";
        };
      };

      config.environment.systemPackages = with pkgs; [
        ksumsMumble
        mum
        mumble
        foxglove-studio
      ];
    };

    mkHost = { system, modules }:
      lib.nixosSystem {
        inherit system;
        modules = [ unfreeModule ksumsModule ] ++ modules;
      };

  in {
    nixosConfigurations = {
      laptop = mkHost {
        system = "x86_64-linux";
        modules = [
          ./core/base_tools.nix
          ./hosts/laptop/configuration.nix
          { ksums = { role = "laptop"; user = "PitCrew"; }; }
        ];
      };

      server = mkHost {
        system = "x86_64-linux";
        modules = [
          copyparty.nixosModules.default
          ./core/base_tools.nix
          ./hosts/lib-o-yap/configuration.nix
          {
            ksums.role = "server";
            services.copyparty.enable = true;
          }
        ];
      };

      vm = mkHost {
        system = "x86_64-linux";
        modules = [
          # 🔑 THIS MAKES IT BOOTABLE
          ./hosts/vm/hardware-configuration.nix

          ./core/base_tools.nix

          {
            networking.networkmanager.enable = true;

            services.openssh = {
              enable = true;
              settings = {
                PermitRootLogin = "no";
                PasswordAuthentication = false;
              };
            };

            services.tailscale.enable = true;

            networking.firewall.enable = true;
            networking.firewall.allowedTCPPorts = [ 22 ];

            users.users.ksums = {
              isNormalUser = true;
              extraGroups = [ "wheel" "networkmanager" ];
              openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA7nZvbeUa6Qw82RZ5+sdZIIj63D8J6+1VzajO+zbX7T"
              ];
            };

            security.sudo.wheelNeedsPassword = false;
            system.stateVersion = "24.05";
          }
        ];
      };
    };
  };
}
