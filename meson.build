project(
  'gs-plugin-apk2',
  ['vala', 'c'],
  version: '0.0.3',
)

valac = meson.get_compiler('vala')

config_h = configuration_data()
config_h.set_quoted('GETTEXT_PACKAGE', meson.project_name())
config_h.set_quoted('PLUGIN_VERSION', meson.project_version())

configure_file(output: 'config.h', configuration: config_h)

config_dep = valac.find_library(
  'config',
  dirs: meson.project_source_root() / 'src' / 'shared',
)

confinc = include_directories('.')

cargs = [
  '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
  '-DG_LOG_DOMAIN="GsPluginApk2"',
  '-DI_KNOW_THE_GNOME_SOFTWARE_API_IS_SUBJECT_TO_CHANGE',
]

fs = import('fs')
gnome = import('gnome')

subdir('src')

install_data(
  'data/org.gnome.Software.Plugin.Apk2.metainfo.xml',
  install_dir: join_paths(get_option('datadir'), 'metainfo'),
)

subdir('tests')
