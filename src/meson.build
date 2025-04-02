gtk_dep = dependency('gtk4')
appstream_dep = dependency('appstream')
soup_dep = dependency('libsoup-3.0')

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
apk_dep = dependency(
  'apk-polkit-client-2',
  fallback: ['apk-polkit-rs', 'apk_polkit_client_dep'],
)

subdir('vapi')
subdir('gs-plugin-apk2')
