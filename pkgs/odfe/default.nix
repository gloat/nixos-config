# oDFe, the Quake3e-based engine made for DeFRaG (github.com/Defrag-racing/oDFe), built from source for x3d (user,
# 2026-10-27: not the bundle's prebuilt binaries). SDL2, so it runs natively on Wayland (niri). The engine dlopens
# libGL/libvulkan/libcurl/libasound and its renderer from the current directory: home/defrag.nix's `defrag` launcher
# starts it from $out/lib/odfe with those on LD_LIBRARY_PATH. The laptop builds the same engine by hand in ~/oDFe.
{ lib, stdenv, fetchFromGitHub, pkg-config, which, SDL2, curl, alsa-lib, libGL, libx11, vulkan-headers, pcre2 }:

stdenv.mkDerivation {
  pname = "odfe";
  version = "0-unstable-2026-08-05";

  src = fetchFromGitHub {
    owner = "Defrag-racing";
    repo = "oDFe";
    rev = "5c573f4e35d16e0b67450a3cbe100038f55f0653";
    hash = "sha256-aqdBfTS3pT8R93nOKBsnG4+eWLkxsCSoYKpf2B4wdoY=";
  };

  nativeBuildInputs = [ pkg-config which ]; # the Makefile finds pkg-config with `which`
  buildInputs = [ SDL2 curl alsa-lib libGL libx11 vulkan-headers pcre2 ];

  makeFlags = [ "release" "USE_SDL=1" "BUILD_SERVER=0" ];
  enableParallelBuilding = true;

  installPhase = ''
    runHook preInstall
    make install DESTDIR=$out/lib/odfe/ USE_SDL=1 BUILD_SERVER=0
    runHook postInstall
  '';

  meta = {
    description = "Quake III Arena engine for the DeFRaG mod (Quake3e fork)";
    homepage = "https://github.com/Defrag-racing/oDFe";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
