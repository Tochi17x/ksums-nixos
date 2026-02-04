# KSUMS Unified NixOS Flake

A unified NixOS configuration for KSUMS (KSU Motorsports) that supports multiple device roles.

## Device Roles

| Role | Description | Auto-starts |
|------|-------------|-------------|
| `server` | Headless server (lib-o-yap) with CopyParty | SSH, Tailscale, CopyParty |
| `laptop` | Hyprland desktop workstation | Mumble GUI, Foxglove Studio |
| `car` | Embedded Pi in car | mumd (headless Mumble) |

## Configurations

### lib-o-yap (Server)
Your existing server with ZFS, CopyParty, etc.

```bash
sudo nixos-rebuild switch --flake .#lib-o-yap
```

### laptop (Workstation)
Hyprland desktop with Foxglove and Mumble auto-starting on login.

```bash
# First, generate hardware config on the target machine:
nixos-generate-config --show-hardware-config > hosts/laptop/hardware-configuration.nix

# Then rebuild:
sudo nixos-rebuild switch --flake .#laptop
```

### workstation (Generic)
A template that works on any x86_64 device. Customize as needed.

```bash
sudo nixos-rebuild switch --flake .#workstation
```

## Commands

After installation, these commands are available:

```bash
# Smart Mumble client (auto-detects headless vs GUI)
ksums-mumble                    # Auto-detect mode
ksums-mumble --gui              # Force GUI
ksums-mumble --headless         # Force headless

# Foxglove Studio
ksums-foxglove

# Start both Mumble and Foxglove
ksums-desktop
```

## Hyprland Shortcuts

| Key | Action |
|-----|--------|
| Super + F1 | Open Mumble |
| Super + F2 | Open Foxglove |
| Super + F3 | Open both (ksums-desktop) |
| Super + Return | Terminal (kitty) |
| Super + D | App launcher (wofi) |
| Super + Q | Close window |

## Configuration Options

In your NixOS config:

```nix
{
  ksums = {
    role = "laptop";              # server, laptop, or car
    piAddress = "192.168.1.50";   # KSUMS Pi IP
    mumbleUsername = "PitCrew";   # Your Mumble name
    foxglove.enable = true;       # Install Foxglove
    autostart = true;             # Auto-start apps on login
  };
}
```

## Network Setup

```
┌─────────────────────────────────────┐
│  KSUMS Pi (192.168.1.50)            │
│  - Murmur server (voice)            │
│  - CopyParty (file sync)            │
│  - Foxglove WebSocket (telemetry)   │
└──────────────┬──────────────────────┘
               │
    ┌──────────┴──────────┐
    │                     │
┌───┴───┐           ┌─────┴─────┐
│ Car Pi │           │  Laptop   │
│ mumd   │           │ Hyprland  │
│ client │           │ Foxglove  │
└────────┘           │ Mumble    │
                     └───────────┘
```

## Files Structure

```
ksums-unified/
├── flake.nix                 # Main flake
├── core/
│   └── base_tools.nix        # Shared packages
├── hosts/
│   ├── lib-o-yap/            # Server config
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── laptop/               # Laptop config
│       ├── configuration.nix
│       └── hardware-configuration.nix
└── dotfiles/
    └── hyprland.conf         # Hyprland config template
```

## Dev Shell

Test without installing:

```bash
nix develop

# Then use:
mumble mumble://User@192.168.1.50:64738
foxglove-studio
```
