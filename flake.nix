{ description = "A Nix flake to package the Kiro IDE.";

inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; flake-utils.url = "github:numtide/flake-utils"; };

outputs = { self, nixpkgs, flake-utils, ... }: flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    lib = pkgs.lib;

    # --- Configuration ---
    # Metadata fetched from: https://prod.download.desktop.kiro.dev/stable/metadata-linux-x64-stable.json
    version = "0.1.20";

    # This package is only available for x86_64 Linux based on the download URL
    # SHA256 hash obtained via: nix-prefetch-url <URL>
    src = pkgs.fetchurl {
      url = "https://prod.download.desktop.kiro.dev/stable/202407021307-distro-linux-x64-stable/Kiro-0.1.20-linux.tar.gz";
      sha256 = "sha256-R479y7O353tN1S6n8hG+9gZ8f92jK/q/o1qHh+bT8/k=";
    };

    # --- Package Builder ---
    kiro = pkgs.stdenv.mkDerivation {
      pname = "kiro";
      inherit version src;

      # The tarball extracts into a "Kiro" directory
      sourceRoot = "Kiro";

      nativeBuildInputs = [
        pkgs.makeWrapper
        pkgs.copyDesktopItems
        pkgs.autoPatchelfHook # Automatically patches ELF binaries
      ];

      # Runtime dependencies needed by the Electron application
      buildInputs = [
        pkgs.alsa-lib
        pkgs.at-spi2-atk
        pkgs.cups
        pkgs.dbus
        pkgs.expat
        pkgs.gtk3
        pkgs.xorg.libxshmfence
        pkgs.nss
        pkgs.pipewire
      ];

      installPhase = ''
        runHook preInstall

        # Copy the application contents
        mkdir -p $out/lib/kiro
        cp -r ./* $out/lib/kiro/

        # Create a wrapper for the main executable.
        # The --no-sandbox flag is a common workaround for running Electron apps
        # in the Nix store without a setuid chrome-sandbox.
        makeWrapper $out/lib/kiro/kiro $out/bin/kiro \
          --add-flags "--no-sandbox"

        # Install desktop item
        install -Dm644 -t $out/share/applications ./resources/app/resources/linux/kiro.desktop
        substituteInPlace $out/share/applications/kiro.desktop \
          --replace 'Exec=kiro' 'Exec=$out/bin/kiro'

        # Install icon
        install -Dm644 ./resources/app/resources/linux/kiro.png \
          $out/share/icons/hicolor/512x512/apps/kiro.png

        runHook postInstall
      '';

      meta = {
        description = "Kiro - AI-powered development environment";
        homepage = "https://kiro.dev/";
        # The license is proprietary
        license = lib.licenses.unfree;
        # The download URL is specific to x86_64-linux
        platforms = [ "x86_64-linux" ];
        maintainers = with lib.maintainers; [ ]; # Add your handle here if you wish
      };
    };

  in
  {
    # --- Flake Outputs ---
    packages = {
      inherit kiro;
      default = kiro;
    };

    apps = {
      kiro = {
        type = "app";
        program = "${kiro}/bin/kiro";
      };
      default = self.apps.${system}.kiro;
    };

    devShells.default = pkgs.mkShell {
      name = "kiro-shell";
      packages = [ kiro ];
    };
  });
}
