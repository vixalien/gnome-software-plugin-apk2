/*
 * Copyright (C) 2022 Pablo Correa Gomez <ablocorrea@hotmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0+
 */

namespace ApkPluginTest {

  private static void gs_plugins_apk_repo_actions (Gs.PluginLoader plugin_loader) {
    try {
      // PluginJob plugin_job = null;
      // Gs.AppList list = null;
      // Gs.AppQuery query = null;
      // Gs.App? del_repo = null;
      // bool rc;

      // Get apps which are sources
      var query = new Gs.AppQuery ("is-source", Gs.AppQueryTristate.TRUE);
      Gs.PluginJob plugin_job = new Gs.PluginJobListApps (query, Gs.PluginListAppsFlags.NONE);
      var list = plugin_loader.job_process (plugin_job, null);
      Gs.test_flush_main_context ();
      assert_nonnull (list);

      Gs.App? del_repo = null;

      assert_cmpuint (list.length (), CompareOperator.EQ, 3);
      for (int i = 0; i < list.length (); i++) {
        var repo = list.index (i);
        var url = repo.get_url (AppStream.UrlKind.HOMEPAGE);
        var plugin = repo.dup_management_plugin () as Gs.Plugin;
        assert_cmpint (repo.get_kind (), CompareOperator.EQ, AppStream.ComponentKind.REPOSITORY);
        assert_cmpstr (plugin.get_name (), CompareOperator.EQ, "apk");
        if (url == "https://pmos.org/pmos/master") {
          assert_cmpint (repo.get_state (), CompareOperator.EQ, Gs.AppState.AVAILABLE);
        } else {
          assert_cmpint (repo.get_state (), CompareOperator.EQ, Gs.AppState.INSTALLED);
          del_repo = repo;
        }
      }

      // Remove repository
      plugin_job = new Gs.PluginJobManageRepository (del_repo,
                                                     Gs.PluginManageRepositoryFlags.REMOVE);
      var rc = plugin_loader.job_action (plugin_job, null);
      Gs.test_flush_main_context ();
      assert_true (rc);

      // Verify repo status.
      // TODO: With a more complex DBusMock we could even check the count
      // Alternatively, we should check the logs that DBus got called
      assert_cmpint (del_repo.get_kind (), CompareOperator.EQ, AppStream.ComponentKind.REPOSITORY);
      assert_cmpint (del_repo.get_state (), CompareOperator.EQ, Gs.AppState.AVAILABLE);

      // gs_plugin_install_repo (reinstall it, check it works)
      plugin_job = new Gs.PluginJobManageRepository (del_repo,
                                                     Gs.PluginManageRepositoryFlags.INSTALL);
      rc = plugin_loader.job_action (plugin_job, null);
      Gs.test_flush_main_context ();
      assert_true (rc);

      // Verify repo status
      assert_cmpint (del_repo.get_kind (), CompareOperator.EQ, AppStream.ComponentKind.REPOSITORY);
      assert_cmpint (del_repo.get_state (), CompareOperator.EQ, Gs.AppState.INSTALLED);

      // Refresh repos.
      // TODO: Check logs!
      plugin_job = new Gs.PluginJobRefreshMetadata (uint64.MAX,
                                                    Gs.PluginRefreshMetadataFlags.NONE);
      rc = plugin_loader.job_action (plugin_job, null);
      Gs.test_flush_main_context ();
      assert_true (rc);
    } catch (Error error) {
      assert_no_error (error);
    }
  }

  private static void gs_plugins_apk_updates (Gs.PluginLoader plugin_loader) {
    // This is certainly the most complex test
    // Steps:
    // * Add updates should return upgradable and a downgradable
    // packages. This could be extended in the future.
    // * We should enable generic updates plugin and verify that
    // the proxy app is created.
    // * We would like that also some DESKTOP app is created. Do so
    // by returning the package from the hard-coded desktop app in the
    // updates.
    // * Execute update: Verify packages are updated? Needs Mock improvements!
    try {
      // Gs.AppQuery query = null;
      // Gs.PluginJob plugin_job = null;
      // Gs.App? generic_app = null;
      // Gs.App? desktop_app = null;
      // Gs.App? system_app = null;
      // Gs.App foreign_app = null;
      // Gs.AppList update_list = null;
      // bool ret;
      // Gs.AppList? related = null;

      // List updates
      var query = new Gs.AppQuery ("is-for-update", Gs.AppQueryTristate.TRUE,
                                   "refine-flags", Gs.PluginRefineFlags.REQUIRE_UPDATE_DETAILS);
      Gs.PluginJob plugin_job = new Gs.PluginJobListApps (query, Gs.PluginListAppsFlags.NONE);
      var update_list = plugin_loader.job_process (plugin_job, null);
      Gs.test_flush_main_context ();
      assert_nonnull (update_list);

      assert_cmpuint (update_list.length (), CompareOperator.EQ, 2);
      // Check desktop app
      var desktop_app = update_list.index (0);
      assert_nonnull (desktop_app);
      assert_false (desktop_app.has_quirk (Gs.AppQuirk.IS_PROXY));
      assert_cmpstr (desktop_app.get_name (), CompareOperator.EQ, "ApkTestApp");
      assert_cmpuint (desktop_app.get_state (), CompareOperator.EQ, Gs.AppState.UPDATABLE_LIVE);
      // Check generic proxy app
      var generic_app = update_list.index (1);
      assert_nonnull (generic_app);
      assert_true (generic_app.has_quirk (Gs.AppQuirk.IS_PROXY));
      var related = generic_app.get_related ();
      assert_cmpuint (related.length (), CompareOperator.EQ, 1);
      var system_app = related.index (0);
      assert_cmpint (system_app.get_state (), CompareOperator.EQ, Gs.AppState.UPDATABLE_LIVE);

      // Add app that shouldn't be updated
      var foreign_app = new Gs.App ("foreign");
      foreign_app.set_state (Gs.AppState.UPDATABLE_LIVE);
      update_list.add (foreign_app); // No management plugin, should get ignored!
      // Execute update!
      plugin_job = new Gs.PluginJobUpdateApps (update_list,
                                               Gs.PluginUpdateAppsFlags.NO_DOWNLOAD);
      var ret = plugin_loader.job_action (plugin_job, null);
      Gs.test_flush_main_context ();
      assert_true (ret);

      // Check desktop app: TODO: Check logs!
      assert_cmpint (desktop_app.get_state (), CompareOperator.EQ, Gs.AppState.INSTALLED);
      // Check generic proxy app: TODO: Check logs!
      assert_true (generic_app.has_quirk (Gs.AppQuirk.IS_PROXY));
      assert_cmpint (generic_app.get_state (), CompareOperator.EQ, Gs.AppState.INSTALLED);
      related = generic_app.get_related ();
      assert_cmpuint (related.length (), CompareOperator.EQ, 1);
      system_app = related.index (0);
      assert_cmpint (system_app.get_state (), CompareOperator.EQ, Gs.AppState.INSTALLED);
      // Check foreign app: As it was!
      assert_cmpint (foreign_app.get_state (), CompareOperator.EQ, Gs.AppState.UPDATABLE_LIVE);
    } catch (Error error) {
      assert_no_error (error);
    }
  }

  private static void gs_plugins_apk_app_install_remove (Gs.PluginLoader plugin_loader) {
    try {
      // Gs.PluginJob plugin_job = null;
      // Gs.App app = null;
      Gs.AppList list = new Gs.AppList ();
      // Gs.Plugin plugin = null;
      // Gs.AppQuery query = null;
      string[] keywords = { "apk-test", null };
      // bool rc;

      // Search for a non-installed app
      var query = new Gs.AppQuery ("keywords", keywords,
                                   // We force refine to take ownership
                                   "refine-flags", Gs.PluginRefineFlags.REQUIRE_SETUP_ACTION);
      Gs.PluginJob plugin_job = new Gs.PluginJobListApps (query, Gs.PluginListAppsFlags.NONE);
      var app = plugin_loader.job_process_app (plugin_job, null);
      Gs.test_flush_main_context ();
      assert (app != null);
      var plugin = app.dup_management_plugin () as Gs.Plugin;

      // make sure we got the correct app and is managed by us
      assert_cmpstr (app.get_id (), CompareOperator.EQ, "apk-test-app.desktop");
      assert_cmpstr (plugin.get_name (), CompareOperator.EQ, "apk");
      assert_cmpint (app.get_kind (), CompareOperator.EQ, AppStream.ComponentKind.DESKTOP_APP);
      assert_cmpint (app.get_scope (), CompareOperator.EQ, AppStream.ComponentScope.SYSTEM);
      assert_cmpint (app.get_state (), CompareOperator.EQ, Gs.AppState.AVAILABLE);

      // execute installation action
      list.add (app);
      plugin_job = new Gs.PluginJobInstallApps (list,
                                                Gs.PluginInstallAppsFlags.NONE);
      var rc = plugin_loader.job_action (plugin_job, null);
      Gs.test_flush_main_context ();
      assert_true (rc);

      // Verify app is now installed
      assert_cmpint (app.get_state (), CompareOperator.EQ, Gs.AppState.INSTALLED);

      // Execute remove action
      list.remove_all ();
      list.add (app);
      plugin_job = new Gs.PluginJobUninstallApps (list,
                                                  Gs.PluginUninstallAppsFlags.NONE);
      rc = plugin_loader.job_action (plugin_job, null);
      Gs.test_flush_main_context ();
      assert_true (rc);

      // Verify app is now removed
      assert_cmpint (app.get_state (), CompareOperator.EQ, Gs.AppState.AVAILABLE);
    } catch (Error error) {
      assert_no_error (error);
    }
  }

  private static void gs_plugins_apk_refine_app_missing_source (Gs.PluginLoader plugin_loader) {
    try {
      // PluginJob plugin_job = null;
      // Gs.App app = null;
      // Gs.AppQuery query = null;
      string[] keywords = { "no-source", null };
      // Plugin plugin = null;

      // Search for a non-installed app. Use a refine flag not being used
      // to force the run of the refine, but only fix the missing source
      var query = new Gs.AppQuery ("keywords", keywords,
                                   "refine-flags", Gs.PluginRefineFlags.REQUIRE_KUDOS);
      var plugin_job = new Gs.PluginJobListApps (query, Gs.PluginListAppsFlags.NONE);
      var app = plugin_loader.job_process_app (plugin_job, null);
      Gs.test_flush_main_context ();
      assert (app != null);
      var plugin = app.dup_management_plugin () as Gs.Plugin;
      assert_nonnull (plugin);

      // make sure we got the correct app, is managed by us and has the source set
      assert_cmpstr (app.get_id (), CompareOperator.EQ, "no-source-app.desktop");
      assert_cmpstr (plugin.get_name (), CompareOperator.EQ, "apk");
      assert_nonnull (app.get_source_default ());
    } catch (Error error) {
      assert_no_error (error);
    }
  }

  public static int main (string[] args) {
    // string xml = null;
    // string tmp_root = null;
    // PluginLoader plugin_loader = null;
    // Settings settings = null;
    // DBusConnection bus_connection = null;
    // bool ret;
    // int retval;
    string[] allowlist = {
      "apk",
      "generic-updates",
      "appstream",
      null
    };

    Gs.test_init (&args.length, args);

    int retval;

    try {
      var settings = new Settings ("org.gnome.software");
      /* We do not want real data to pollute tests.
       * Might be useful at some point though */
      assert_true (settings.set_strv ("external-appstream-urls", {}));

      Environment.set_variable ("GS_XMLB_VERBOSE", "1", true);

      /* Adapted from upstream dummy/gs-self-test.c */
      var xml = "<?xml version=\"1.0\"?>\n"
        + "<components origin=\"alpine-test\" version=\"0.9\">\n"
        + "  <component type=\"desktop\">\n"
        + "    <id>apk-test-app.desktop</id>\n"
        + "    <name>ApkTestApp</name>\n"
        + "    <summary>Alpine Package Keeper test app</summary>\n"
        + "    <pkgname>apk-test-app</pkgname>\n"
        + "  </component>\n"
        + "  <component type=\"desktop\">\n"
        + "    <id>no-source-app.desktop</id>\n"
        + "    <name>NoSourceApp</name>\n"
        + "    <summary>App with missing source in metadata</summary>\n"
        + "    <info>\n"
        + "      <filename>/usr/share/apps/no-source-app.desktop</filename>\n"
        + "    </info>\n"
        + "  </component>\n"
        + "  <info>\n"
        + "    <scope>system</scope>\n"
        + "  </info>\n"
        + "</components>\n";
      Environment.set_variable ("GS_SELF_TEST_APPSTREAM_XML", xml, true);

      /* Needed for appstream plugin to store temporary data! */
      var tmp_root = DirUtils.make_tmp ("gnome-software-apk-test-XXXXXX");
      assert_true (tmp_root != null);
      Environment.set_variable ("GS_SELF_TEST_CACHEDIR", tmp_root, true);

      var bus_connection = Bus.get_sync (BusType.SESSION, null);
      /* we can only load this once per process */
      var plugin_loader = new Gs.PluginLoader (bus_connection, bus_connection);
      /* plugin_loader.status_changed.connect(gs_plugin_loader_status_changed_cb); */
      plugin_loader.add_location (LOCALPLUGINDIR);
      plugin_loader.add_location (SYSTEMPLUGINDIR);
      var ret = plugin_loader.setup (allowlist, null, null);
      assert_true (ret);
      assert_true (plugin_loader.get_enabled ("apk"));
      assert_true (plugin_loader.get_enabled ("generic-updates"));
      assert_true (plugin_loader.get_enabled ("appstream"));

      Test.add_data_func ("/gnome-software/plugins/apk/repo-actions",
                          (TestDataFunc) gs_plugins_apk_repo_actions);
      Test.add_data_func ("/gnome-software/plugins/apk/app-install-remove",
                          (TestDataFunc) gs_plugins_apk_app_install_remove);
      Test.add_data_func ("/gnome-software/plugins/apk/updates",
                          (TestDataFunc) gs_plugins_apk_updates);
      Test.add_data_func ("/gnome-software/plugins/apk/missing-source",
                          (TestDataFunc) gs_plugins_apk_refine_app_missing_source);
      Test.add_data_func ("/gnome-software/plugins/apk/refine-app-missing-source",
                          (TestDataFunc) gs_plugins_apk_refine_app_missing_source);
      retval = Test.run ();

      /* Clean up. */
      Gs.utils_rmtree (tmp_root);
    } catch (Error error) {
      critical ("Error: %s", error.message);
      return 1;
    }

    return retval;
  }
}
