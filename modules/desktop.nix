# The desktop on every graphical host (g814, x3d): niri on Wayland, Noctalia, PipeWire, fonts, keyd.
# Disks are LUKS-encrypted, so greetd auto-logs into niri after unlock (the laptop's Sunshine also needs a live
# graphical session to stream).
{ lib, pkgs, user, ... }:
{
  programs.niri = {
    enable = true;
    # File dialogs via xdg-desktop-portal-gtk instead of Nautilus (drops Nautilus,
    # its localsearch/tinysparql indexer and gnome-user-share).
    useNautilus = false;
  };
  # Kept from niri's defaults: xdg-desktop-portal-gnome (screencasting) and gnome-keyring
  # (Secret Service for Brave/gh). Trimmed: screen-reader speech stack and GNOME's SSH agent.
  services.speechd.enable = false;
  services.gnome.gcr-ssh-agent.enable = false;

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "niri-session";
        inherit user;
      };
      default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
    };
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # niri with our patches: pkgs/niri/*.patch, made in the ~/niri workspace (branch gloat of an upstream clone,
  # exported with niri-export). niri is then compiled here instead of downloaded (a few minutes per niri update).
  # If a patch stops applying after `nix flake update`, rebase the gloat branch onto the new tag in ~/niri.
  nixpkgs.overlays = [ (final: prev: {
    niri = prev.niri.overrideAttrs (o: {
      patches = (o.patches or [ ]) ++ lib.filesystem.listFilesRecursive ../pkgs/niri;
    });
    # Noctalia (spawned from niri's config) provides bar, launcher, notifications and lock screen.
    # Its lock screen header and panel are swapped for ours (home/noctalia/lockscreen): big clock and date at the top,
    # bare weather icons and the session buttons at the bottom. Pinned to its version: recheck after updates.
    # Built without ddcutil: DDC/CI probes froze the PC's BenQ ZOWIE XL controls on 2026-08-28 (fixed only by
    # unplugging it for 60 s). Brightness stays with the laptop panel's backlight.
    noctalia-shell = assert prev.noctalia-shell.version == "4.7.6";
      (prev.noctalia-shell.override { ddcutilSupport = false; }).overrideAttrs (o: {
        postInstall = (o.postInstall or "") + ''
          cp ${../home/noctalia/lockscreen}/*.qml $out/share/noctalia-shell/Modules/LockScreen/
        '';
      });
  }) ];
  environment.systemPackages = with pkgs; [
    noctalia-shell
    xwayland-satellite
  ];
  services.upower.enable = true; # battery widget
  hardware.bluetooth.enable = true;

  # Syncthing (home/syncthing.nix) between g814 and x3d, tailscale0 only.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22000 ];

  # Chromium/Electron apps (Brave) run native Wayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Brave policies for every profile, locked in the UI; brave://policy lists them.
  # Shields and site permissions stay per profile, in the UI. Names checked against Brave 1.97's binary.
  environment.etc."brave/policies/managed/gloat.json".text = builtins.toJSON {
    # Telemetry off.
    BraveP3AEnabled = false;
    BraveStatsPingEnabled = false;
    BraveWebDiscoveryEnabled = false;
    MetricsReportingEnabled = false;
    # Features not used.
    BraveRewardsDisabled = true;
    BraveWalletDisabled = true;
    BraveVPNDisabled = true;
    BraveAIChatEnabled = false;
    BraveNewsDisabled = true;
    BraveTalkDisabled = true;
    SyncDisabled = true;
    # Privacy: AMP and tracking-URL redirects, tracking query parameters stripped, generic language headers, GPC.
    BraveDeAmpEnabled = true;
    BraveDebouncingEnabled = true;
    BraveTrackingQueryParametersFilteringEnabled = true;
    BraveReduceLanguageEnabled = true;
    BraveGlobalPrivacyControlEnabled = true;
    WebRtcIPHandling = "disable_non_proxied_udp";
    NetworkPredictionOptions = 2; # no preloading
    SearchSuggestEnabled = false;
    # Passwords and payment details live in KeePassXC.
    PasswordManagerEnabled = false;
    AutofillAddressEnabled = false;
    AutofillCreditCardEnabled = false;
    PaymentMethodQueryEnabled = false;
  };

  # Hack Nerd Font is the default for everything (UI, documents, terminals); emoji fall back to Noto.
  fonts.packages = with pkgs; [ nerd-fonts.hack noto-fonts noto-fonts-color-emoji ];
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Hack Nerd Font" ];
    serif = [ "Hack Nerd Font" ];
    monospace = [ "Hack Nerd Font Mono" ];
    emoji = [ "Noto Color Emoji" ];
  };

  # Caps Lock: Esc when tapped, Ctrl when held (keyd grabs the keyboards and types through a virtual one).
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main.capslock = "overload(control, esc)";
    };
  };
  # libinput pairs disable-while-typing only with internal keyboards. Keys now arrive from keyd's virtual
  # keyboard, so mark it internal, or the touchpad's dwt (home/niri/config.kdl) silently stops working.
  environment.etc."libinput/local-overrides.quirks".text = ''
    [keyd virtual keyboard]
    MatchUdevType=keyboard
    MatchName=keyd virtual keyboard
    AttrKeyboardIntegration=internal
  '';
}
