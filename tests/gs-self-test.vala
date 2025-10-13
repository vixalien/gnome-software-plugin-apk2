/*
 * Copyright (C) 2022 Pablo Correa Gomez <ablocorrea@hotmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0+
 */

namespace ApkPluginTest {

  private static void gs_plugins_apk_repo_actions (Gs.PluginLoader plugin_loader) {
    try {
      // Get apps which are sources
      var query = new Gs.AppQuery ("component-kinds", new AppStream.ComponentKind[] { AppStream.ComponentKind.REPOSITORY });
      var list_apps_plugin_job = new Gs.PluginJobListApps (query, Gs.PluginListAppsFlags.NONE);
      var ret = plugin_loader.job_process (list_apps_plugin_job, null);
      var list = list_apps_plugin_job.get_result_list ();
      Gs.test_flush_main_context ();
      assert_nonnull (list);

      Gs.App? del_repo = null;

      assert_cmpuint (list.length (), CompareOperator.EQ, 3);
      for (int i = 0; i < list.length (); i++) {
        var repo = list.index (i);
        var url = repo.get_url (AppStream.UrlKind.HOMEPAGE);
        var plugin = repo.dup_management_plugin () as Gs.Plugin;
        assert_cmpint (repo.get_kind (), CompareOperator.EQ, AppStream.ComponentKind.REPOSITORY);
        assert_cmpstr (plugin.get_name (), CompareOperator.EQ, "apk2");
        if (url == "https://pmos.org/pmos/master") {
          assert_cmpint (repo.get_state (), CompareOperator.EQ, Gs.AppState.AVAILABLE);
        } else {
          assert_cmpint (repo.get_state (), CompareOperator.EQ, Gs.AppState.INSTALLED);
          del_repo = repo;
        }
      }

      // Remove repository
      var remove_repo_plugin_job = new Gs.PluginJobManageRepository (del_repo,
                                                                     Gs.PluginManageRepositoryFlags.REMOVE);
      var rc = plugin_loader.job_process (remove_repo_plugin_job, null);
      Gs.test_flush_main_context ();
      assert_true (rc);

      // Verify repo status.
      // TODO: With a more complex DBusMock we could even check the count
      // Alternatively, we should check the logs that DBus got called
      assert_cmpint (del_repo.get_kind (), CompareOperator.EQ, AppStream.ComponentKind.REPOSITORY);
      assert_cmpint (del_repo.get_state (), CompareOperator.EQ, Gs.AppState.AVAILABLE);

      // gs_plugin_install_repo (reinstall it, check it works)
      var install_repo_plugin_job = new Gs.PluginJobManageRepository (del_repo,
                                                                      Gs.PluginManageRepositoryFlags.INSTALL);
      rc = plugin_loader.job_process (install_repo_plugin_job, null);
      Gs.test_flush_main_context ();
      assert_true (rc);

      // Verify repo status
      assert_cmpint (del_repo.get_kind (), CompareOperator.EQ, AppStream.ComponentKind.REPOSITORY);
      assert_cmpint (del_repo.get_state (), CompareOperator.EQ, Gs.AppState.INSTALLED);

      // Refresh repos.
      // TODO: Check logs!
      var refresh_plugin_job = new Gs.PluginJobRefreshMetadata (uint64.MAX,
                                                                Gs.PluginRefreshMetadataFlags.NONE);
      rc = plugin_loader.job_process (refresh_plugin_job, null);
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
      // List updates
      var query = new Gs.AppQuery ("is-for-update", Gs.AppQueryTristate.TRUE,
                                   "refine-require-flags", Gs.PluginRefineRequireFlags.UPDATE_DETAILS);
      var list_apps_job = new Gs.PluginJobListApps (query, Gs.PluginListAppsFlags.NONE);
      var rc = plugin_loader.job_process (list_apps_job, null);
      var update_list = list_apps_job.get_result_list ();
      Gs.test_flush_main_context ();
      assert_nonnull (update_list);

      assert_cmpuint (update_list.length (), CompareOperator.EQ, 2);
      // Check desktop app
      var desktop_app = update_list.index (0);
      assert_nonnull (desktop_app);
      assert_false (desktop_app.has_quirk (Gs.AppQuirk.IS_PROXY));
      assert_cmpstr (desktop_app.get_name (), CompareOperator.EQ, "ApkTestApp");
      assert_cmpuint (desktop_app.get_state (), CompareOperator.EQ, Gs.AppState.UPDATABLE_LIVE);
      //// Check generic proxy app
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
      var update_job = new Gs.PluginJobUpdateApps (update_list,
                                                   Gs.PluginUpdateAppsFlags.NO_DOWNLOAD);
      var ret = plugin_loader.job_process (update_job, null);
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
      Gs.AppList list = new Gs.AppList ();
      string[] keywords = { "apk-test" };

      // Search for a non-installed app
      var query = new Gs.AppQuery ("keywords", keywords,
                                   // We force refine to take ownership
                                   "refine-require-flags", Gs.PluginRefineRequireFlags.SETUP_ACTION);
      var list_apps_job = new Gs.PluginJobListApps (query, Gs.PluginListAppsFlags.NONE);
      var success = plugin_loader.job_process (list_apps_job, null);
      var app = list_apps_job.get_result_list ().index (0);
      Gs.test_flush_main_context ();
      assert (app != null);
      var plugin = app.dup_management_plugin () as Gs.Plugin;

      // make sure we got the correct app and is managed by us
      assert_cmpstr (app.get_id (), CompareOperator.EQ, "apk-test-app.desktop");
      assert_cmpstr (plugin.get_name (), CompareOperator.EQ, "apk2");
      assert_cmpint (app.get_kind (), CompareOperator.EQ, AppStream.ComponentKind.DESKTOP_APP);
      assert_cmpint (app.get_scope (), CompareOperator.EQ, AppStream.ComponentScope.SYSTEM);
      assert_cmpint (app.get_state (), CompareOperator.EQ, Gs.AppState.AVAILABLE);

      // execute installation action
      list.add (app);

      var install_job = new Gs.PluginJobInstallApps (list,
                                                     Gs.PluginInstallAppsFlags.NONE);
      var rc = plugin_loader.job_process (install_job, null);
      Gs.test_flush_main_context ();
      assert_true (rc);

      // Verify app is now installed
      assert_cmpint (app.get_state (), CompareOperator.EQ, Gs.AppState.INSTALLED);

      // Execute remove action
      list.remove_all ();
      list.add (app);
      var uninstall_job = new Gs.PluginJobUninstallApps (list,
                                                         Gs.PluginUninstallAppsFlags.NONE);
      rc = plugin_loader.job_process (uninstall_job, null);
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
      string[] keywords = { "no-source" };

      // Search for a non-installed app. Use a refine flag not being used
      // to force the run of the refine, but only fix the missing source
      var query = new Gs.AppQuery ("keywords", keywords,
                                   "refine-require-flags", Gs.PluginRefineRequireFlags.KUDOS);
      var list_apps_job = new Gs.PluginJobListApps (query, Gs.PluginListAppsFlags.NONE);
      plugin_loader.job_process (list_apps_job, null);
      var app = list_apps_job.get_result_list ().index (0);
      Gs.test_flush_main_context ();
      assert (app != null);
      var plugin = app.dup_management_plugin () as Gs.Plugin;
      assert_nonnull (plugin);

      // make sure we got the correct app, is managed by us and has the source set
      assert_cmpstr (app.get_id (), CompareOperator.EQ, "no-source-app.desktop");
      assert_cmpstr (plugin.get_name (), CompareOperator.EQ, "apk2");
      assert_nonnull (app.get_default_source ());
    } catch (Error error) {
      assert_no_error (error);
    }
  }

  public static int main (string[] args) {
    string[] allowlist = {
      "apk2",
      "generic-updates",
      "appstream",
      null
    };

    Gs.test_init (&args.length, (char* * *) &args);

    int retval;

    try {
      var settings = new Settings ("org.gnome.software");
      /* We do not want real data to pollute tests.
       * Might be useful at some point though */
      assert_true (settings.set_strv ("external-appstream-urls", {}));

      Environment.set_variable ("GS_XMLB_VERBOSE", "1", true);

      /* Adapted from upstream dummy/gs-self-test.c */
      var xml = """<?xml version="1.0"?>
<components origin="alpine-test" version="0.9">
  <component type="desktop">
    <id>apk-test-app.desktop</id>
    <name>ApkTestApp</name>
    <summary>Alpine Package Keeper test app</summary>
    <pkgname>apk-test-app</pkgname>
  </component>
  <component type="desktop">
    <id>no-source-app.desktop</id>
    <name>NoSourceApp</name>
    <summary>App with missing source in metadata</summary>
    <info>
      <filename>/usr/share/apps/no-source-app.desktop</filename>
    </info>
  </component>
  <info>
    <scope>system</scope>
  </info>
</components>""";
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
      assert_true (plugin_loader.get_enabled ("apk2"));
      assert_true (plugin_loader.get_enabled ("generic-updates"));
      assert_true (plugin_loader.get_enabled ("appstream"));

      Test.add_data_func ("/gnome-software/plugins/apk/repo-actions", () => {
        gs_plugins_apk_repo_actions (plugin_loader);
      });
      Test.add_data_func ("/gnome-software/plugins/apk/app-install-remove", () => {
        gs_plugins_apk_app_install_remove (plugin_loader);
      });
      Test.add_data_func ("/gnome-software/plugins/apk/updates", () => {
        gs_plugins_apk_updates (plugin_loader);
      });
      Test.add_data_func ("/gnome-software/plugins/apk/missing-source", () => {
        gs_plugins_apk_refine_app_missing_source (plugin_loader);
      });
      retval = Test.run ();

      /* Clean up. */
      try {
        Gs.utils_rmtree (tmp_root);
      } catch {
      }
    } catch (Error error) {
      critical ("Error: %s", error.message);
      return 1;
    }

    return retval;
  }
}
