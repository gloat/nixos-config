# Hybrid graphics: Intel UHD 770 drives the panel and encodes for Sunshine (Quick Sync);
# the RTX 4080 Laptop sleeps (RTD3) until woken with `nvidia-offload <cmd>`.
# Keep the BIOS/MUX in hybrid (Optimus) mode.
{ config, pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [ intel-media-driver vpl-gpu-rt ];
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  services.xserver.videoDrivers = [ "modesetting" "nvidia" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = true;
    modesetting.enable = true;
    nvidiaSettings = false;
    powerManagement.enable = true;
    powerManagement.finegrained = true;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      # Verified on hardware 2026-10-19: 0000:00:02.0 Intel UHD, 0000:01:00.0 RTX 4080 Laptop.
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
}
