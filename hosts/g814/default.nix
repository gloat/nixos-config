{ lib, pkgs, user, ... }:
let
  # The PC (x3d, bare-metal NixOS since 2026-10-26): its ~/.ssh/g814 key (keys/x3d.pub).
  pcKeys = [ (lib.trim (builtins.readFile ../../keys/x3d.pub)) ];
  # Keyboard backlight: dim white with the lid open (AC or battery), off with the lid closed.
  # The bottom LED strip (lightbar zone) stays off.
  kbdLight = pkgs.writeShellApplication {
    name = "kbd-light";
    runtimeInputs = [ pkgs.asusctl pkgs.gawk ];
    text = ''
      sleep 0.5 # let the AC/lid state settle after the ACPI event
      asusctl aura power lightbar # no flags = lightbar off in every power state
      lid=$(awk '{print $2}' /proc/acpi/button/lid/LID0/state)
      if [ "$lid" != open ]; then
        asusctl leds set off
      else
        asusctl aura effect static -c ffffff
        asusctl leds set low
      fi
    '';
  };
in {
  imports = [
    ../common.nix
    ../workstation.nix
    ./hardware-configuration.nix
    ./disko.nix
    ./boot.nix
    ./nvidia.nix
    ../../modules/desktop.nix
    ./remote.nix
    ./security.nix
    ../../modules/monitoring.nix
  ];

  networking.hostName = "g814";

  # Exporters for void's Prometheus (gloat.ing/fleet), tailscale0 only. The NVIDIA one runs on AC only (user,
  # 2026-10-25), so it never keeps the 4080 out of runtime suspend on battery.
  fleet.monitoring = {
    enable = true;
    gpu = "nvidia";
    nvidiaOnAcOnly = true;
  };
  networking.networkmanager = {
    enable = true;
    wifi.powersave = false; # radio napping causes stream stutter
  };

  # Nix builds (niri compiles locally) run at idle priority, so they never starve the desktop: Breeze needs a full
  # core to speak in real time, and Emilie cut in and out during a niri build (2026-10-24).
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  services.fwupd.enable = true;
  zramSwap.enable = true;
  boot.tmp.cleanOnBoot = true;
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # ASUS platform: fan profiles, charge limit, keyboard backlight
  services.asusd.enable = true;
  # asusd's unit bind-mounts /etc/asusd but nothing creates it on a fresh install.
  systemd.tmpfiles.rules = [ "d /etc/asusd 0755 root root -" ];
  services.power-profiles-daemon.enable = true;
  # acpid reruns kbd-light on AC plug/unplug and lid events; niri also runs it once at login.
  services.acpid = {
    enable = true;
    acEventCommands = "${kbdLight}/bin/kbd-light";
    lidEventCommands = "${kbdLight}/bin/kbd-light";
  };

  # Nothing suspends on its own (the lid only locks, see remote.nix), so a forgotten laptop on battery
  # powers off cleanly at 10% instead of dying. The default, HybridSleep, needs hibernation, which we don't have.
  services.upower = {
    percentageLow = 20;
    percentageCritical = 12;
    percentageAction = 10;
    criticalPowerAction = "PowerOff";
  };

  # Webcam off switch for the bar's privacy eye (home/noctalia/privacy): let the video group de-authorize the
  # USB webcam, which unbinds its driver and makes /dev/video* disappear until it's re-authorized.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="322e", ATTR{idProduct}=="2122", RUN+="${pkgs.coreutils}/bin/chgrp video /sys%p/authorized", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys%p/authorized"
  '';

  users.users.${user} = {
    extraGroups = [ "networkmanager" "video" "input" ];
    openssh.authorizedKeys.keys = pcKeys;
  };
  security.sudo.wheelNeedsPassword = true;
  # nixos-rebuild and systemctl over SSH without a password prompt, so the PC can deploy here.
  # Effectively root for anyone holding the PC's g814 key; everything else still asks.
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
    kbdLight
  ];

  system.stateVersion = "26.05";
}
