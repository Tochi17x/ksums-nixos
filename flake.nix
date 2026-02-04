{
  description = "KSUMS NixOS - Server (lib-o-yap) + Laptop (Hyprland + Foxglove + Mumble)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    copyparty.url = "github:9001/copyparty";
    copyparty.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, copyparty, ... }@inputs: 
    let
      # Support multiple systems
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      });

      # Shared KSUMS module
      ksumsModule = { config, lib, pkgs, ... }: with lib; {
        options.ksums = {
          role = mkOption {
            type = types.enum [ "server" "laptop" "car" ];
            default = "laptop";
            description = "Device role in KSUMS setup";
          };

          piAddress = mkOption {
            type = types.str;
            default = "192.168.1.50";
            description = "IP address of the KSUMS Pi (Murmur server)";
          };

          mumbleUsername = mkOption {
            type = types.str;
            default = "Crew";
            description = "Mumble username";
          };

          foxglove.enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable Foxglove Studio";
          };

          autostart = mkOption {
            type = types.bool;
            default = true;
            description = "Auto-start Mumble and Foxglove on login";
          };
        };

        config = let
          cfg = config.ksums;
          
          # Smart Mumble script
          ksumsMumble = pkgs.writeScriptBin "ksums-mumble" ''
            #!${pkgs.python3}/bin/python3
            """KSUMS Smart Mumble - auto-detects headless vs GUI"""
            import os, sys, subprocess, time, shutil

            def is_headless():
                if os.environ.get('DISPLAY') or os.environ.get('WAYLAND_DISPLAY'):
                    return False
                xdg = os.environ.get('XDG_RUNTIME_DIR', "")
                if xdg and os.path.exists(os.path.join(xdg, 'wayland-0')):
                    return False
                return True

            def main():
                server = os.environ.get('MUMBLE_HOST', '${cfg.piAddress}')
                port = os.environ.get('MUMBLE_PORT', '64738')
                user = os.environ.get('MUMBLE_USER', '${cfg.mumbleUsername}')
                
                headless = '--headless' in sys.argv or (is_headless() and '--gui' not in sys.argv)
                
                if headless:
                    print(f"[KSUMS] Headless mode - mumd -> {server}:{port} as {user}")
                    cmd = ['${pkgs.mum}/bin/mumd', '--server', f'{server}:{port}', '--username', user]
                else:
                    print(f"[KSUMS] GUI mode - mumble -> {server}:{port} as {user}")
                    cmd = ['${pkgs.mumble}/bin/mumble', f'mumble://{user}@{server}:{port}']
                
                while True:
                    try:
                        r = subprocess.run(cmd)
                        if r.returncode == 0: break
                        print(f"[KSUMS] Exited ({r.returncode}), reconnecting in 5s...")
                    except KeyboardInterrupt:
                        break
                    except Exception as e:
                        print(f"[KSUMS] Error: {e}")
                    time.sleep(5)

            if __name__ == '__main__':
                main()
          '';

          # Foxglove launcher script
          foxgloveLauncher = pkgs.writeScriptBin "ksums-foxglove" ''
            #!/usr/bin/env bash
            echo "[KSUMS] Starting Foxglove Studio"
            echo "[KSUMS] Pi WebSocket: ws://${cfg.piAddress}:8765"
            exec ${pkgs.foxglove-studio}/bin/foxglove-studio "$@"
          '';

          # Combined launcher for desktop
          ksumsDesktop = pkgs.writeScriptBin "ksums-desktop" ''
            #!/usr/bin/env bash
            echo "[KSUMS] Starting desktop apps..."
            
            # Start Mumble in background
            ${ksumsMumble}/bin/ksums-mumble --gui &
            
            # Start Foxglove
            ${foxgloveLauncher}/bin/ksums-foxglove &
            
            echo "[KSUMS] Apps started. Mumble + Foxglove running."
            wait
          '';

        in mkMerge [
          # Common packages for all roles
          {
            environment.systemPackages = with pkgs; [
              ksumsMumble
              foxgloveLauncher
              ksumsDesktop
              mumble
              mum
              mcap-cli
              python3
            ] ++ lib.optionals cfg.foxglove.enable [ foxglove-studio ];
          }

          # Laptop role - Hyprland + GUI apps
          (mkIf (cfg.role == "laptop") {
            # Hyprland desktop
            programs.hyprland = {
              enable = true;
              xwayland.enable = true;
            };

            # Display manager
            services.greetd = {
              enable = true;
              settings = {
                default_session = {
                  command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
                  user = "greeter";
                };
              };
            };

            # Audio
            security.rtkit.enable = true;
            services.pipewire = {
              enable = true;
              alsa.enable = true;
              alsa.support32Bit = true;
              pulse.enable = true;
            };

            # XDG portal for screen sharing
            xdg.portal = {
              enable = true;
              extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
            };

            # Fonts
            fonts.packages = with pkgs; [
              noto-fonts
              noto-fonts-cjk-sans
              noto-fonts-emoji
              font-awesome
              (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
            ];

            # Common desktop packages
            environment.systemPackages = with pkgs; [
              # Hyprland essentials
              waybar
              wofi
              kitty
              mako
              swww
              grim
              slurp
              wl-clipboard
              brightnessctl
              pamixer
              networkmanagerapplet
              # File manager
              nautilus
              # Browser
              firefox
            ];
          })

          # Server role - headless services
          (mkIf (cfg.role == "server") {
            # No GUI, just services
            services.openssh.enable = true;
            services.tailscale.enable = true;
          })
        ];
      };

    in {
      # NixOS Module export
      nixosModules = {
        ksums = ksumsModule;
        default = ksumsModule;
      };

      # Packages
      packages = forAllSystems (system: let
        pkgs = nixpkgsFor.${system};
      in {
        ksums-mumble = pkgs.writeScriptBin "ksums-mumble" ''
          #!${pkgs.python3}/bin/python3
          import os, sys, subprocess, time
          def is_headless():
              return not (os.environ.get('DISPLAY') or os.environ.get('WAYLAND_DISPLAY'))
          server = os.environ.get('MUMBLE_HOST', '192.168.1.50')
          port = os.environ.get('MUMBLE_PORT', '64738')
          user = os.environ.get('MUMBLE_USER', 'Crew')
          headless = '--headless' in sys.argv or (is_headless() and '--gui' not in sys.argv)
          cmd = ['${pkgs.mum}/bin/mumd', '--server', f'{server}:{port}', '--username', user] if headless else ['${pkgs.mumble}/bin/mumble', f'mumble://{user}@{server}:{port}']
          while True:
              try:
                  if subprocess.run(cmd).returncode == 0: break
              except KeyboardInterrupt: break
              except: pass
              time.sleep(5)
        '';
        default = self.packages.${system}.ksums-mumble;
      });

      # NixOS Configurations
      nixosConfigurations = {
        # Server - lib-o-yap (your existing server)
        lib-o-yap = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ksumsModule
            copyparty.nixosModules.default
            ./core/base_tools.nix
            ./hosts/lib-o-yap/configuration.nix
            ({ pkgs, ... }: {
              nixpkgs.overlays = [ copyparty.overlays.default ];
              
              ksums = {
                role = "server";
                foxglove.enable = false;
                autostart = false;
              };

              services.copyparty = {
                enable = true;
                user = "shop";
                group = "users";
                settings = {
                  i = "0.0.0.0";
                  p = [ 3923 ];
                };
                volumes = {
                  "/data" = {
                    path = "/data";
                    access = { r = "*"; rw = [ "*" ]; };
                    flags = { e2d = true; nodupe = true; };
                  };
                };
              };
            })
          ];
        };

        # Laptop - Hyprland workstation
        laptop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ksumsModule
            ({ config, pkgs, lib, ... }: {
              imports = [ ./hosts/laptop/configuration.nix ];
              
              ksums = {
                role = "laptop";
                piAddress = "192.168.1.50";
                mumbleUsername = "PitCrew";
                foxglove.enable = true;
                autostart = true;
              };

              # Auto-start KSUMS apps on Hyprland login
              environment.etc."xdg/hypr/hyprland.conf".text = lib.mkAfter ''
                # KSUMS Auto-start
                exec-once = ksums-mumble --gui
                exec-once = ksums-foxglove
              '';
            })
          ];
        };

        # Generic workstation template (works on any x86_64 device)
        workstation = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ksumsModule
            ({ config, pkgs, lib, modulesPath, ... }: {
              imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
              
              # Basic boot - override in hardware-configuration.nix
              boot.loader.systemd-boot.enable = lib.mkDefault true;
              boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
              
              networking.hostName = "ksums-workstation";
              networking.networkmanager.enable = true;

              ksums = {
                role = "laptop";
                piAddress = "192.168.1.50";
                mumbleUsername = "Crew";
                foxglove.enable = true;
                autostart = true;
              };

              # User
              users.users.ksums = {
                isNormalUser = true;
                extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
                initialPassword = "changeme";
              };

              security.sudo.wheelNeedsPassword = false;
              
              # Nix settings
              nix.settings.experimental-features = [ "nix-command" "flakes" ];

              system.stateVersion = "24.05";
            })
          ];
        };
      };

      # Dev shell for testing
      devShells = forAllSystems (system: let
        pkgs = nixpkgsFor.${system};
      in {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            python3
            mum
            mumble
            foxglove-studio
            mcap-cli
          ];
          shellHook = ''
            echo "KSUMS Dev Shell"
            echo ""
            echo "Commands:"
            echo "  mumble mumble://User@192.168.1.50:64738  - GUI client"
            echo "  mumd --server 192.168.1.50:64738 --username User  - Headless"
            echo "  foxglove-studio  - Open Foxglove"
            echo ""
            export MUMBLE_HOST=192.168.1.50
            export MUMBLE_PORT=64738
          '';
        };
      });
    };
}
