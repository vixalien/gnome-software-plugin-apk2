cargs = [
  '-DG_LOG_DOMAIN="GsPluginApk2"',
  '-DI_KNOW_THE_GNOME_SOFTWARE_API_IS_SUBJECT_TO_CHANGE',
  '-DGS_PLUGIN_APK_VERSION="@0@"'.format(meson.project_version()),
]

plugin_install_dir = gnome_software_dep.get_variable(
  'plugindir',
  default_value: '/usr/lib/gnome-software/plugins-20',
)

library(
  meson.project_name(),
  sources: files('lib.vala'),
  install: true,
  install_dir: plugin_install_dir,
  c_args: cargs,
  dependencies: [
    gnome_software_dep,
    appstream_dep,
    gtk_dep,
    soup_dep,
  ],
  vala_args: [
    '--vapidir', meson.current_build_dir() / '..' / 'vapi',
  ],
)
