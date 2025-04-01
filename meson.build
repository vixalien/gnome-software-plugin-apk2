project('gs-plugin-apk2', ['vala', 'c'], version: 'nightly')

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
