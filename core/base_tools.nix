{ config, lib, pkgs, ... }: {
  # Core system packages
  environment.systemPackages = with pkgs; [
    mcap-cli
    python3
    neovim
    git
    btop
    neofetch
    lazygit
    wget
    curl
    unzip
    ripgrep
    fd
  ];

  # SSH and Tailscale
  services.openssh.enable = true;
  services.tailscale.enable = true;

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}
