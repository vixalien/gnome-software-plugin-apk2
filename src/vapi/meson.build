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

gnomesoftware_include_files = []

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

foreach header : gs_headers
  gnomesoftware_include_files += join_paths(
    gnome_software_dep.get_variable('includedir') / gnome_software_dep.name(),
    header,
  )
endforeach

message(gnome_software_dep.get_variable('libdir'))

gnome_software_gir = custom_target(
  output: 'Gs-21.gir',
  command: [
    find_program('g-ir-scanner'),
    # '--warn-all',
    '--include=AppStream-1.0',
    '--include=Gdk-4.0',
    '--include=Soup-3.0',
    '--namespace=Gs',
    '--identifier-prefix=Gs',
    '--symbol-prefix=gs',
    '--pkg=gnome-software',
    '--library-path', gnome_software_dep.get_variable('libdir') / gnome_software_dep.name(),
    '--library', 'gnomesoftware',
    '-DI_KNOW_THE_GNOME_SOFTWARE_API_IS_SUBJECT_TO_CHANGE=1',
    '--output=@OUTPUT@',
    gnomesoftware_include_files,
  ],
  depends: [],
  install: true,
  install_dir: get_option('datadir') / 'gir-1.0',
)

gnome_software_vapi = gnome.generate_vapi(
  'gnome-software',
  sources: gnome_software_gir.full_path(),
  metadata_dirs: meson.current_source_dir(),
  packages: [
    'AppStream-1.0',
    gtk_dep.name(),
  ],
  install: true,
)
