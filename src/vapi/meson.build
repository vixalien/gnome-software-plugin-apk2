gs_headers = [
  'gnome-software.h',
  'gs-app.h',
  'gs-app-collation.h',
  'gs-app-list.h',
  'gs-app-permissions.h',
  'gs-app-query.h',
  'gs-appstream.h',
  'gs-category.h',
  'gs-category-manager.h',
  'gs-desktop-data.h',
  'gs-download-utils.h',
  'gs-external-appstream-utils.h',
  'gs-icon.h',
  'gs-icon-downloader.h',
  'gs-ioprio.h',
  'gs-job-manager.h',
  'gs-key-colors.h',
  'gs-metered.h',
  'gs-odrs-provider.h',
  'gs-os-release.h',
  'gs-plugin.h',
  'gs-plugin-event.h',
  'gs-plugin-helpers.h',
  'gs-plugin-job.h',
  'gs-plugin-job-cancel-offline-update.h',
  'gs-plugin-job-download-upgrade.h',
  'gs-plugin-job-file-to-app.h',
  'gs-plugin-job-launch.h',
  'gs-plugin-job-list-apps.h',
  'gs-plugin-job-list-categories.h',
  'gs-plugin-job-list-distro-upgrades.h',
  'gs-plugin-job-manage-repository.h',
  'gs-plugin-job-refine.h',
  'gs-plugin-job-refresh-metadata.h',
  'gs-plugin-job-trigger-upgrade.h',
  'gs-plugin-job-install-apps.h',
  'gs-plugin-job-uninstall-apps.h',
  'gs-plugin-job-update-apps.h',
  'gs-plugin-job-url-to-app.h',
  'gs-plugin-loader.h',
  'gs-plugin-loader-sync.h',
  'gs-plugin-types.h',
  'gs-plugin-vfuncs.h',
  'gs-remote-icon.h',
  'gs-rewrite-resources.h',
  'gs-test.h',
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
  output: 'Gs-49.gir',
  command: [
    find_program('g-ir-scanner'),
    # '--warn-all',
    '--c-include=gnome-software.h',
    '--include=AppStream-1.0',
    '--include=Gdk-4.0',
    '--include=Soup-3.0',
    '--namespace=Gs',
    '--nsversion=49',
    '--identifier-prefix=Gs',
    '--symbol-prefix=gs',
    '--pkg', 'gnome-software',
    '--library-path', gnome_software_dep.get_variable('libdir') / gnome_software_dep.name(),
    '--library', '/usr/lib/gnome-software/libgnomesoftware.so.23',
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

apk_gir = custom_target(
  # 'gnome-software',
  output: 'ApkPolkit2-0.gir',
  command: [
    find_program('g-ir-scanner'),
    # '--warn-all',
    '--c-include=apk-polkit-client.h',
    '--c-include=apk-polkit-client-bitflags.h',
    '--include=Gtk-4.0',
    '--namespace=ApkPolkit2',
    '--pkg', 'apk-polkit-client-2',
    '--library-path', apk_dep.get_variable('libdir') / apk_dep.name(),
    '--library', '/usr/lib/libapk-polkit-client2.so.3',
    '--output=@OUTPUT@',
    '-I', '/usr/include/apk-polkit-2',
    '/usr/include/apk-polkit-2/apk-polkit-client.h',
    '/usr/include/apk-polkit-2/apk-polkit-client-bitflags.h',
    '--warn-all',
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
