project('gs-plugin-apk2', ['vala', 'c'], version: 'nightly')

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

gnome_software_dep = dependency(
  'gnome-software',
  version: '>=46.0',
  fallback: ['gnome-software', 'libgnomesoftware_dep'],
  default_options: [
    'malcontent=false',
    'packagekit=false',
    'webapps=false',
    'fwupd=false',
    'hardcoded_foss_webapps=false',
    'hardcoded_proprietary_webapps=false',
    'external_appstream=true',
    # TODO: disable this
    'gtk_doc=true',
    'sysprof=disabled',
  ],
)

subdir('src')

install_data(
  'data/org.gnome.Software.Plugin.Apk2.metainfo.xml',
  install_dir: join_paths(get_option('datadir'), 'metainfo'),
)
