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
        hello = final.callPackage ./birdhy.nix {};
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

    formatter = eachSystem (system: pkgsFor.${system}.alejandra);
  };
}
