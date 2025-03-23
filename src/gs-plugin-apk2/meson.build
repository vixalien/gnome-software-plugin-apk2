cargs = [
  '-DG_LOG_DOMAIN="GsPluginApk2"',
  '-DI_KNOW_THE_GNOME_SOFTWARE_API_IS_SUBJECT_TO_CHANGE',
  '-DGS_PLUGIN_APK_VERSION="@0@"'.format(meson.project_version()),
]

plugin_install_dir = gnome_software_dep.get_variable(
  'plugindir',
  default_value: '/usr/lib/gnome-software/plugins-20',
)

custom_target(
  # 'lib.c',
  # 'lib.c',
  input: files('lib.vala'),
  output: 'vala.c',
  command: [
    'valac',
    '@INPUT@',
    '--library', meson.project_name(),
    '--output', '@OUTPUT@',
    '--pkg', 'gnome-software',
    '--pkg', 'gtk4',
    '--pkg', 'appstream',
    '--pkg', 'libsoup-3.0',
    # '--Xcc', '"-DI_KNOW_THE_GNOME_SOFTWARE_API_IS_SUBJECT_TO_CHANGE"',
    '--ccode',
    '--keep-going',
    '--vapidir', meson.current_build_dir() / '..' / 'vapi',
    '--color',
  ],
  install: true,
  install_dir: plugin_install_dir,
)

# library(
#   'gs_plugin_apk2',
#   vala_header: 'gs_plugin_apk2.h',
#   # vala_vapi: 'gs_plugin_apk2-0.0.vapi',
#   sources: files('lib.vala'),
#   install: true,
#   install_dir: plugin_install_dir,
#   c_args: cargs,
#   dependencies: [
#     # gnome_software_vapi,
#     # appstream_dep,
#     gtk_dep,
#     soup_dep,
#   ],
#   vala_args: [
#     # '-I', '/usr/include/gnome-software/',
#     '--vapidir', meson.current_build_dir() / '..' / 'vapi',
#     # '--girdir', meson.current_build_dir() / '..' / 'vapi',
#     # '--metadatadir', meson.current_source_dir() / '..' / 'vapi',
#     '--pkg', 'appstream',
#     '--pkg', 'gnome-software',
#     # '--pkg', 'Gs-21',
#   ],
# )
