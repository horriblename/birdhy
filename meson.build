project('birdhy', 'vala', 'c')

dependencies = [
  dependency('gio-2.0'),
  dependency('gtk4'),
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gee-0.8'),
  dependency('gtk4-layer-shell-0'),
]

add_global_arguments('--enable-experimental-non-null', language : 'vala')

json = static_library('json', 'src/json/lib.vala', dependencies: dependencies)

# lib = static_library('data', 'src/lib.vala', dependencies: dependencies, link_with: [json])

sources = files('src/main.vala', 'src/client.vala', 'src/result.vala', 'src/monitor.vala', 'src/icon_lookup.vala')

executable('birdhy', sources, dependencies: dependencies, link_with: [json], install: true)
