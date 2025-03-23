gnome = import('gnome')

gnome_software_dep = dependency(
  'gnome-software',
  version: '>=45.0',
  # fallback: ['gnome-software', 'libgnomesoftware_dep'],
  # default_options: [
  #   'malcontent=false',
  #   'packagekit=false',
  #   'webapps=false',
  #   'fwupd=false',
  #   'hardcoded_foss_webapps=false',
  #   'hardcoded_proprietary_webapps=false',
  #   'external_appstream=true',
  #   'gtk_doc=false',
  #   'sysprof=disabled',
  # ],
)

gs_headers = [
  'gs-app.h',
  'gs-app-list.h',
  'gs-app-collation.h',
  'gs-app-permissions.h',
  'gs-app-query.h',
  'gs-category.h',
  'gs-category-manager.h',
  'gs-desktop-data.h',
  'gs-download-utils.h',
  'gs-enums.h',
  'gs-icon.h',
  'gs-icon-downloader.h',
  'gs-metered.h',
  'gs-odrs-provider.h',
  'gs-os-release.h',
  'gs-plugin.h',
  'gs-plugin-helpers.h',
  'gs-plugin-job.h',
  'gs-plugin-job-list-apps.h',
  'gs-plugin-job-list-categories.h',
  'gs-plugin-job-list-distro-upgrades.h',
  'gs-plugin-job-manage-repository.h',
  'gs-plugin-job-refine.h',
  'gs-plugin-job-refresh-metadata.h',
  'gs-plugin-job-update-apps.h',
  'gs-plugin-vfuncs.h',
  'gs-remote-icon.h',
  'gs-rewrite-resources.h',
  'gs-utils.h',
  'gs-worker-thread.h',
]

gnomesoftware_include_files = []
gnomesoftware_c_include_flags = []

foreach header : gs_headers
  gnomesoftware_include_files += join_paths(
    gnome_software_dep.get_variable('includedir') / gnome_software_dep.name(),
    header,
  )
  gnomesoftware_c_include_flags += '--c-include=' + header
endforeach

message(gnome_software_dep.get_variable('libdir'))

gnome_software_gir = custom_target(
  # 'gnome-software',
  output: 'Gs-20.gir',
  command: [
    find_program('g-ir-scanner'),
    # '--warn-all',
    '--c-include=gnome-software.h',
    '--include=AppStream-1.0',
    '--include=Gdk-4.0',
    '--include=Soup-3.0',
    '--namespace=Gs',
    '--identifier-prefix=Gs',
    '--symbol-prefix=gs',
    '--pkg', 'gnome-software',
    '--library-path', gnome_software_dep.get_variable('libdir') / gnome_software_dep.name(),
    '--library', '/usr/lib/gnome-software/libgnomesoftware.so.20',
    '-DI_KNOW_THE_GNOME_SOFTWARE_API_IS_SUBJECT_TO_CHANGE=1',
    '--output=@OUTPUT@',
    '-I', '/usr/include/gnome-software',
    '/usr/include/gnome-software/gnome-software.h',
    gnomesoftware_include_files,
  ],
  install: true,
  install_dir: get_option('datadir') / 'gir-1.0',
)

gnome_software_vapi = gnome.generate_vapi(
  'gnome-software',
  sources: gnome_software_gir.full_path(),
  metadata_dirs: meson.current_source_dir(),
  packages: [
    appstream_dep.name(),
    gtk_dep.name(),
  ],
  install: true,
)

appstream_vapi = gnome.generate_vapi(
  'appstream',
  sources: '/usr/share/gir-1.0/AppStream-1.0.gir',
  metadata_dirs: meson.current_source_dir(),
  packages: [
    gtk_dep.name(),
  ],
  install: true,
)

apk_gir = custom_target(
  # 'gnome-software',
  output: 'ApkPolkit2-0.gir',
  command: [
    find_program('g-ir-scanner'),
    # '--warn-all',
    '--c-include=apk-polkit-client.h',
    '--include=Gtk-4.0',
    '--namespace=ApkPolkit2',
    '--pkg', 'apk-polkit-client-2',
    '--library-path', apk_dep.get_variable('libdir') / apk_dep.name(),
    '--library', '/usr/lib/libapk-polkit-client2.so.2',
    '--output=@OUTPUT@',
    '-I', '/usr/include/apk-polkit-2',
    '/usr/include/apk-polkit-2/apk-polkit-client.h',
    '/usr/include/apk-polkit-2/apk-polkit-client-bitflags.h',
  ],
  install: true,
  install_dir: get_option('datadir') / 'gir-1.0',
)

apk_vapi = gnome.generate_vapi(
  'apk-polkit-client-2',
  sources: apk_gir.full_path(),
  metadata_dirs: meson.current_source_dir(),
  packages: [
    gtk_dep.name(),
  ],
  install: true,
)
