# PLACEHOLDER - Generate with: nixos-generate-config --show-hardware-config
# Then replace this file with the output

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Generic laptop settings - replace with your actual hardware
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ]; # or kvm-amd for AMD

  # PLACEHOLDER - replace with your actual disk UUID
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  
  # Enable firmware
  hardware.enableRedistributableFirmware = true;
}
