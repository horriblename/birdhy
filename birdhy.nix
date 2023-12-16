{
  stdenv,
  meson,
  vala,
  vala-language-server,
  pkg-config,
  ninja,
  cmake,
  gtk4,
  glib,
  libgee,
  gobject-introspection,
  gtk4-layer-shell,
}:
stdenv.mkDerivation {
  pname = "apps";
  version = "0.1";
  src = ./.;
  nativeBuildInputs = [
    meson
    vala
    vala-language-server
    pkg-config
    ninja
  ];
  buildInputs = [
    gtk4
    glib
    libgee
    gobject-introspection
    gtk4-layer-shell
  ];
}
