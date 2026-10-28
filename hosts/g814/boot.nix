# systemd-boot + LUKS unlock either at the laptop keyboard or over SSH from the PC:
#   ssh g814-unlock   -> prompts for the LUKS passphrase, then boot continues.
# Initrd networking is wired-only (onboard Realtek 2.5GbE, r8169).
# 26.05 uses systemd stage 1: the forced `systemctl default` command runs the password agent.
{ lib, ... }:
let
  # The PC (x3d, bare-metal NixOS since 2026-10-26): its ~/.ssh/g814 key (keys/x3d.pub).
  pcKeys = [ (lib.trim (builtins.readFile ../../keys/x3d.pub)) ];
in {
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 20;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelParams = [ "ip=dhcp" ];
  boot.initrd.availableKernelModules = [ "r8169" ];
  boot.initrd.network = {
    enable = true;
    ssh = {
      enable = true;
      port = 2222;
      authorizedKeys = map (key: ''command="systemctl default" ${key}'') pcKeys;
      # Generated once at install (see INSTALL.md); distinct from the main host key.
      hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
    };
  };

  # The initrd's networkd leaves its state in /run/systemd/netif ("offline" when the cable is out), and nothing
  # updates it after boot: the running system uses NetworkManager. timesyncd trusted it and never synced the clock
  # (found 2026-10-25 by the fleet dashboard's ClockNotSynced alert). Without the files it assumes it's online.
  systemd.services.initrd-netif-cleanup = {
    description = "Remove the initrd networkd's stale state";
    wantedBy = [ "sysinit.target" ];
    before = [ "sysinit.target" "systemd-timesyncd.service" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/run/current-system/sw/bin/rm -rf /run/systemd/netif";
    };
  };
}
