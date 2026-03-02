{
  description = "dunst (local checkout) - build + dev tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        mkDunst =
          {
            withX11 ? true,
            withWayland ? true,
          }:
          pkgs.stdenv.mkDerivation (finalAttrs: {
            pname = "dunst";
            version = "dev";

            src = self;

            nativeBuildInputs = [
              pkgs.perl
              pkgs.pkg-config
              pkgs.which
              pkgs.systemd
              pkgs.makeWrapper
            ];

            buildInputs =
              [
                pkgs.cairo
                pkgs.dbus
                pkgs.gdk-pixbuf
                pkgs.glib
                pkgs.libnotify
                pkgs.pango
                pkgs.librsvg
              ]
              ++ pkgs.lib.optionals withX11 [
                pkgs.xorg.libX11
                pkgs.xorg.libXScrnSaver
                pkgs.xorg.libXinerama
                pkgs.xorg.xorgproto
                pkgs.xorg.libXrandr
              ]
              ++ pkgs.lib.optionals withWayland [
                pkgs.wayland
                pkgs.wayland-protocols
              ];

            outputs = [
              "out"
              "man"
            ];

            makeFlags =
              [
                "PREFIX=$(out)"
                "VERSION=$(version)"
                "SYSCONFDIR=$(out)/etc"
                "SERVICEDIR_DBUS=$(out)/share/dbus-1/services"
                "SERVICEDIR_SYSTEMD=$(out)/lib/systemd/user"
              ]
              ++ pkgs.lib.optional (!withX11) "X11=0"
              ++ pkgs.lib.optional (!withWayland) "WAYLAND=0";

            postInstall = ''
              wrapProgram $out/bin/dunst \
                --set GDK_PIXBUF_MODULE_FILE "$GDK_PIXBUF_MODULE_FILE"

              wrapProgram $out/bin/dunstctl \
                --prefix PATH : "${
                  pkgs.lib.makeBinPath [
                    pkgs.coreutils
                    pkgs.dbus
                  ]
                }"

              substituteInPlace \
                $out/share/zsh/site-functions/_dunstctl \
                $out/share/bash-completion/completions/dunstctl \
                $out/share/fish/vendor_completions.d/{dunstctl,dunstify}.fish \
                --replace-fail "jq" "${pkgs.lib.getExe pkgs.jq}"
            '';
          });
      in
      {
        packages = rec {
          dunst = mkDunst { };
          dunst-x11 = mkDunst { withWayland = false; };
          dunst-wayland = mkDunst { withX11 = false; };
          default = dunst;
        };

        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.default;
          exePath = "/bin/dunst";
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.default ];
          nativeBuildInputs = [
            pkgs.gnumake
            pkgs.pkg-config
            pkgs.which
            pkgs.perl
            pkgs.jq
          ];
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}

