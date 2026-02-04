{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Use the systemd-boot EFI boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.supportedFilesystems = [ "zfs" ];
  boot.kernelModules = [ "zfs" ];

  fileSystems = {
    "/".options = [ "compress=zstd" ];
    "/home".options = [ "compress=zstd" ];
    "/nix".options = [ "compress=zstd" "noatime" ];
  };

  services.btrfs.autoScrub.enable = true;

  networking.hostName = "lib-o-yap";
  networking.hostId = "bcc4454e"; # required for ZFS
  networking.networkmanager.enable = true;

  # Firewall for CopyParty
  networking.firewall.allowedTCPPorts = [ 3923 ];

  # User
  users.users.shop = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  system.stateVersion = "24.05";
}
