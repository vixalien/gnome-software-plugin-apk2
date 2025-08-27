plugin_install_dir = gnome_software_dep.get_variable(
  'plugindir',
  default_value: '/usr/lib/gnome-software/plugins-20',
)

plugin_apk_lib = library(
  'gs_plugin_apk2',
  sources: files('lib.vala'),
  install: true,
  install_dir: plugin_install_dir,
  c_args: cargs,
  include_directories: confinc,
  dependencies: [
    config_dep,
    apk_dep,
    gnome_software_dep,
    appstream_dep,
    gtk_dep,
    soup_dep,
  ],
  vala_args: [
    '--vapidir', meson.current_build_dir() / '..' / 'vapi',
  ],
)
