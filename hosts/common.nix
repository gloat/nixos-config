# Shared by every host (g814, x3d, web): Nix itself, locale, the user and a few base tools.
# What only the session machines need (nh, nix-ld) is in workstation.nix.
{ pkgs, user, ... }:
{
  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  programs.fish.enable = true;
  users.users.${user} = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" ];
  };

  environment.systemPackages = with pkgs; [
    git
    ripgrep
    fd
    htop
  ];
}
