# systemd-boot + LUKS unlock at the PC's keyboard or over SSH from the laptop (the PC is wired):
#   ssh x3d-unlock   -> prompts for the LUKS passphrase, then boot continues.
# Same setup as hosts/g814/boot.nix. Initrd networking is wired-only (onboard Realtek 5GbE RTL8126, r8169).
{ lib, ... }:
let
  laptopKeys = [ (lib.trim (builtins.readFile ../../keys/g814.pub)) ];
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
      authorizedKeys = map (key: ''command="systemctl default" ${key}'') laptopKeys;
      # Generated once at install (see INSTALL.md); distinct from the main host key.
      hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
    };
  };

  # The initrd's networkd leaves stale state in /run/systemd/netif and timesyncd then never syncs: see the same
  # service in hosts/g814/boot.nix (found 2026-10-25).
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
