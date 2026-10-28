# nixos-config

A few excerpts from the NixOS flake that runs my machines, full setup to come soon (still making final tweaks.) Every change is a diff and a bootable generation, so rolling back is a reboot. 

- **g814**, the laptop: ASUS ROG Strix G18 (i9-13980HX, RTX 4080 Laptop). Development box for Quake 3 engine work.
- **x3d**, the desktop: Ryzen 7 9800X3D, RX 9070 XT. Games, and a local LLM on the GPU.

The full flake also runs the public server behind [gloat.ing](https://gloat.ing). That part stays private for now, so this repo won't build on its own; it's here to read.

## What's in it

- `flake.nix`: one `mkHost` for every machine: nixos-26.05, home-manager, disko, and nixos-unstable only for the
  few packages that need to move faster.
- `hosts/common.nix`: the base every host shares.
- `hosts/g814/`, `hosts/x3d/`: LUKS2 + btrfs, unlocked at the keyboard or over SSH into the initrd (`boot.nix`, systemd
  stage 1). On the laptop, hybrid graphics: the Intel iGPU drives the panel and the NVIDIA GPU sleeps until a program
  asks for it (`nvidia.nix`).
- `modules/desktop.nix`: niri on Wayland, greetd, PipeWire, fonts, keyd, and an overlay that builds niri with the
  patches below.
- `pkgs/niri/`: my patches to [niri](https://github.com/YaLTeR/niri):
  - Quake-style linear mouse acceleration (`accel-linear`)
  - `hide-window` / `show-window` (a drop-down terminal) and `toggle-touchpad`
  - per-window open and close animations in window rules
  - `fill-single-column`: a lone column fills the screen
- `pkgs/odfe/`: [oDFe](https://github.com/Defrag-racing/oDFe), the Quake3e-based engine for DeFRaG, built from source.

The niri patches are under niri's license (GPL-3.0-or-later).
