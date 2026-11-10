{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  cargo,
  rustc,
  cmake,
  ninja,
  pkg-config,
  qt6,
  qt6Packages,
  alsa-lib,
  libpulseaudio,
  libsecret,
  openssl,
}:

let
  corrosion = fetchFromGitHub {
    owner = "corrosion-rs";
    repo = "corrosion";
    tag = "v0.6.1"; # pin in CMakeLists.txt
    hash = "sha256-ppuDNObfKhneD9AlnPAvyCRHKW3BidXKglD1j/LE9CM=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "swiftify";
  version = "0.25.1";

  src = fetchFromGitHub {
    owner = "swiftify-org";
    repo = "swiftify";
    tag = "v${finalAttrs.version}";
    hash = "sha256-W7R3w0ogX3JvBlEshKkrAzgNbzwrOfqusIBgAQkqVDY=";
  };

  cargoRoot = "spotify-core";
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) src;
    sourceRoot = "${finalAttrs.src.name}/spotify-core";
    hash = "sha256-zmipkJpoyxmMnrwIbSp4t6N1iUQlpk7oCiBBrQKpgMU=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    cargo
    rustc
    rustPlatform.cargoSetupHook
    qt6.wrapQtAppsHook
    qt6.qtshadertools
  ];
  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwebsockets
    qt6.qtwayland
    qt6Packages.qtkeychain
    qt6Packages.qcoro
    alsa-lib
    libpulseaudio
    libsecret
    openssl
  ];

  # corrosion runs cargo from the build dir; make sure it finds the vendored config
  preConfigure = "ln -s spotify-core/.cargo .cargo";
  preBuild = ''
    export QML2_IMPORT_PATH=${qt6.qtdeclarative}/${qt6.qtbase.qtQmlPrefix}
  '';

  cmakeFlags = [
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DFETCHCONTENT_SOURCE_DIR_CORROSION=${corrosion}"
    "-DSWIFTIFY_DOWNLOAD_ICON_FONT=OFF"
    "-DSWIFTIFY_DOWNLOAD_INTERFACE_FONT=OFF"
    "-DBUILD_TESTING=OFF"
  ];

  meta.license = lib.licenses.gpl3Plus;
})
