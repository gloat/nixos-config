# The PC "x3d": MSI MAG X870 TOMAHAWK WIFI, Ryzen 7 9800X3D, RX 9070 XT, Samsung 990 PRO 2 TB, Realtek 5GbE (wired).
# Gaming and the second control center. Bare-metal NixOS from 2026-10-26 (Windows and its WSL host `wsl` wiped).
# Same base as the laptop (user, 2026-10-26): LUKS2 + btrfs, systemd-boot, unlock at the keyboard or over SSH, niri.
# Latency tuning (kernel, VRR, amdgpu power profile) comes after a stock-kernel baseline.
{ lib, pkgs, user, ... }:
let
  # The laptop drives this machine with its key ~/.ssh/x3d (keys/g814.pub).
  laptopKeys = [ (lib.trim (builtins.readFile ../../keys/g814.pub)) ];
in {
  imports = [
    ../common.nix
    ../workstation.nix
    ./hardware-configuration.nix
    ./disko.nix
    ./boot.nix
    ../../modules/desktop.nix
    ./security.nix
    ../../modules/monitoring.nix
  ];

  networking.hostName = "x3d";
  networking.networkmanager.enable = true;

  # Exporters for void's Prometheus (gloat.ing/fleet), tailscale0 only. AMD: node_exporter's drm collector.
  fleet.monitoring = {
    enable = true;
    gpu = "amd";
  };

  # Nix builds (niri compiles locally) run at idle priority, so they never take frames from a game.
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";

  # Fans and board temperatures: the MSI board's Nuvoton NCT6687D, which the kernel's nct6683 driver finds on its own
  # (nct6775 doesn't; probed 2026-10-26). node_exporter's hwmon collector reads it for the fleet dashboard.
  boot.kernelModules = [ "nct6683" ];

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;
  services.fwupd.enable = true;
  zramSwap.enable = true;
  boot.tmp.cleanOnBoot = true;
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # RX 9070 XT (RDNA4: kernel 6.18, Mesa 26.1) and the 9800X3D's iGPU, both amdgpu + RADV. The iGPU is the second
  # Vulkan device: pick the 9070 XT explicitly where a tool splits work (llama.cpp did on Windows).
  # Early KMS, so the LUKS prompt already runs at the monitor's native mode.
  hardware.amdgpu.initrd.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # The games: Quake Live, Momentum Mod, Path of Exile 1/2. Steam downloads its own runtime (~1 GB) on first start.
  # GE-Proton (user, 2026-10-27): the community Proton build, pinned by nixpkgs; pick it per game in Steam's
  # Compatibility tab.
  programs.steam = {
    enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  # LACT (user, 2026-10-27): the RX 9070 XT's fan curve, power limit and power profile (GUI `lact gui`, settings in
  # /etc/lact/config.yaml, outside git). Talks to amdgpu's sysfs, never DDC/CI, so the monitor is safe. Change one
  # setting at a time and measure (the latency project).
  services.lact.enable = true;

  users.users.${user} = {
    extraGroups = [ "networkmanager" "video" "input" ];
    openssh.authorizedKeys.keys = laptopKeys;
  };
  security.sudo.wheelNeedsPassword = true;
  # nixos-rebuild and systemctl without a password prompt (as on the laptop), so the laptop can deploy here.
  # Effectively root for anyone holding the laptop's x3d key; everything else still asks.
  security.sudo.extraRules = [{
    users = [ user ];
    commands = map (command: { inherit command; options = [ "NOPASSWD" ]; }) [
      "/run/current-system/sw/bin/nixos-rebuild"
      "/run/current-system/sw/bin/systemctl"
    ];
  }];

  environment.systemPackages = with pkgs; [
    pciutils
    usbutils
  ];

  system.stateVersion = "26.05";
}
