cargs = [
  '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
  '-DG_LOG_DOMAIN="GsPluginApk2"',
  '-DI_KNOW_THE_GNOME_SOFTWARE_API_IS_SUBJECT_TO_CHANGE',
]

plugin_install_dir = gnome_software_dep.get_variable(
  'plugindir',
  default_value: '/usr/lib/gnome-software/plugins-20',
)

library(
  'gs_plugin_apk2',
  sources: files('lib.vala'),
  install: true,
  install_dir: plugin_install_dir,
  c_args: cargs,
  include_directories: confinc,
  dependencies: [
    config_dep,
    apk_dep,
    # appstream_vapi,
    gnome_software_dep,
    # gnome_software_vapi,
    appstream_dep,
    gtk_dep,
    soup_dep,
  ],
  vala_args: [
    '--vapidir', meson.current_build_dir() / '..' / 'vapi',
  ],
)
