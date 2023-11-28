{
  description = "A very basic flake";
  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (nixpkgs) lib;
    eachSystem = lib.genAttrs ["x86_64-linux"];
    pkgsFor = eachSystem (
      system:
        import nixpkgs {
          localSystem = system;
          overlays = [self.overlays.default];
        }
    );
  in {
    overlays = {
      default = final: _prev: {
        hello = final.stdenv.mkDerivation {
          pname = "apps";
          version = "0.1";
          src = ./.;
          nativeBuildInputs = with final; [
            meson
            vala
            vala-language-server
            pkg-config
            ninja
            cmake
          ];
          buildInputs = with final; [
            gtk4
            glib
            libgee
            gobject-introspection
            gtk4-layer-shell
          ];
        };
      };
    };

    packages = eachSystem (system: {
      default = self.packages.${system}.hello;
      inherit (pkgsFor.${system}) hello;
    });
    devShells = eachSystem (system: let
      pkgs = pkgsFor.${system};
    in {
      default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          meson
          vala
          vala-language-server
          pkg-config
          ninja
          cmake
          #
          glib
          libgee
          gobject-introspection
        ];
        buildInputs = with pkgs; [
          gtk4
          glib
          libgee
          gobject-introspection
          gtk4-layer-shell
        ];
      };
    });
  };
}
