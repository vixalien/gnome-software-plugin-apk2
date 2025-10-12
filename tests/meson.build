cargs = [
  '-DI_KNOW_THE_GNOME_SOFTWARE_API_IS_SUBJECT_TO_CHANGE',
]

# Create a configuration file for compile-time constants
test_config_h = configuration_data()
test_config_h.set_quoted('LOCALPLUGINDIR', fs.parent(plugin_apk_lib.full_path()))
test_config_h.set_quoted('SYSTEMPLUGINDIR', plugin_install_dir)

config_vapi = valac.find_library('config', dirs: meson.current_source_dir())

configure_file(output: 'test_config.h', configuration: test_config_h)

test = executable(
  'gs-self-test-apk',
  sources: [
    files('gs-self-test.vala'),
  ],
  dependencies: [
    config_vapi,
    gnome_software_dep,
    soup_dep,
    apk_dep,
    appstream_dep,
    gtk_dep,
  ],
  link_with: [plugin_apk_lib],
  install: false,
  vala_args: [
    '--vapidir', meson.current_build_dir() / '..' / 'src' / 'vapi',
  ],
  c_args: [
    cargs,
    '-I/usr/include/gnome-software',
    # '-DGSTEST_H',
    # '-g',
    # '-O0',
    '-DLOCALPLUGINDIR="@0@"'.format(fs.parent(plugin_apk_lib.full_path())),
    '-DSYSTEMPLUGINDIR="@0@"'.format(plugin_install_dir),
  ],
)

test_env = [
  'G_TEST_SRCDIR=@0@'.format(meson.current_source_dir()),
  'G_TEST_BUILDDIR=@0@'.format(meson.current_build_dir()),
  'MALLOC_CHECK_=2',
]

test('gs-self-test-apk', test, env: test_env)
