public const ApkPolkit2.DetailsFlags APK_POLKIT_CLIENT_DETAILS_FLAGS_ALL = 0xFF;
public const uint GS_APP_PROGRESS_UNKNOWN = uint.MAX;

enum ApkPackageState {
  Available,
  Installed,
  PendingInstall,
  PendingRemoval,
  Upgradable,
  Downgradable,
  Reinstallable
}

struct ApkdPackage {
  string name;
  string version;
  string description;
  string license;
  string stagingVersion;
  string url;
  ulong installedSize;
  ulong size;
  ApkPackageState packageState;
}

public class GsPluginApk2 : Gs.Plugin {
  private unowned ApkPolkit2.Proxy proxy;

  construct {
    add_rule (RUN_BEFORE, "icons");
    add_rule (RUN_BEFORE, "generic-updates");
    /* We want to get packages from appstream and refine them */
    add_rule (RUN_AFTER, "appstream");

    this.proxy = null;
  }

  /**
   * gs_plugin_apk_variant_to_apkd:
   * @dict: a `a{sv}` GVariant representing a package
   * @pkg: an ApkdPackage pointer where to place the data
   *
   * Receives a GVariant dictionary representing a package and fills an
   * ApkdPackage with the fields available in the dictionary. Returns
   * a boolean depending on whether the dictionary contains or not an error
   * field.
   **/
  private bool apk_variant_to_apkd (Variant dict, ref ApkdPackage pkg) {
    string error_str;
    if (!dict.lookup ("name", "s", out pkg.name)) {
      return false;
    }
    if (dict.lookup ("error", "s", out error_str)) {
      warning (@"Package $(pkg.name) could not be unpacked: $error_str");
      return false;
    }

    dict.lookup ("version", "s", out pkg.version);
    dict.lookup ("description", "s", out pkg.description);
    dict.lookup ("license", "s", out pkg.license);
    dict.lookup ("url", "s", out pkg.url);
    dict.lookup ("staging_version", "s", out pkg.stagingVersion);
    dict.lookup ("installed_size", "t", out pkg.installedSize);
    dict.lookup ("size", "t", out pkg.size);
    dict.lookup ("package_state", "u", out pkg.packageState);

    return true;
  }

  /**
   * apk_to_app_state:
   * @state: A ApkPackageState
   *
   * Convenience function which converts ApkdPackageState to a GsAppState.
   **/
  private Gs.AppState apk_to_app_state (ApkPackageState state) {
    switch (state) {
    case Installed:
    case PendingRemoval:
      return Gs.AppState.INSTALLED;
    case PendingInstall:
    case Available:
      return Gs.AppState.AVAILABLE;
    case Downgradable:
    case Reinstallable:
    case Upgradable:
      return Gs.AppState.UPDATABLE_LIVE;
    default:
      assert_not_reached ();
      return Gs.AppState.UNKNOWN;
    }
  }

  /**
   * apk_package_to_app:
   * @pkg: A ApkPackage
   *
   * Convenience function which converts a ApkdPackage to a GsApp.
   **/
  private Gs.App apk_package_to_app (ref ApkdPackage pkg) {
    string cache_name = "%s-%s".printf (pkg.name, pkg.version);
    // Gs.App app = plugin.cache_lookup(cache_name);
    Gs.App app = null;

    if (app != null) {
      return app;
    }

    app = new Gs.App (pkg.name);

    app.set_kind (AppStream.ComponentKind.GENERIC);
    app.set_bundle_kind (AppStream.BundleKind.PACKAGE);
    app.set_scope (AppStream.ComponentScope.SYSTEM);
    app.set_allow_cancel (false);
    app.add_source (pkg.name);
    app.set_name (Gs.AppQuality.UNKNOWN, pkg.name);
    app.set_summary (Gs.AppQuality.UNKNOWN, pkg.description);
    app.set_url (AppStream.UrlKind.HOMEPAGE, pkg.url);
    app.set_origin ("alpine");
    app.set_origin_hostname ("alpinelinux.org");
    app.set_management_plugin (this);
    app.set_size_installed (Gs.SizeType.VALID, pkg.installedSize);
    app.set_size_download (Gs.SizeType.VALID, pkg.size);
    app.add_quirk (Gs.AppQuirk.PROVENANCE);
    app.set_metadata ("GnomeSoftware::PackagingFormat", "apk");
    app.set_state (apk_to_app_state (pkg.packageState));
    app.set_version (pkg.version);
    if (app.get_state () == Gs.AppState.UPDATABLE_LIVE) {
      app.set_update_version (pkg.stagingVersion);
    }
    cache_add (cache_name, app);

    return app;
  }

  public async override bool setup_async (GLib.Cancellable? cancellable) throws Error {
    debug ("APK plugin version: %s", Config.PLUGIN_VERSION);

    try {
      proxy = yield ApkPolkit2.DBusProxy.new_for_connection (this.get_system_bus_connection (),
        DBusProxyFlags.NONE,
        "dev.Cogitri.apkPolkit2",
        "/dev/Cogitri/apkPolkit2",
        cancellable);
    } catch (Error local_error) {
      DBusError.strip_remote_error (local_error);
      throw local_error;
    }

    ((DBusProxy) proxy).set_default_timeout (int.MAX);

    return true;
  }

  public async override bool refresh_metadata_async (uint64 cache_age_secs,
                                                     Gs.PluginRefreshMetadataFlags flags,
                                                     Gs.PluginEventCallback callback,
                                                     GLib.Cancellable? cancellable) throws Error {
    debug ("Refreshing repositories");

    yield proxy.call_update_repositories (cancellable);

    updates_changed ();

    return true;
  }

  /**
   * gs_plugin_apk_get_source:
   * @app: The GsApp
   *
   * Convenience function that verifies that the app only has a single source.
   * Returns the corresponding source if successful or NULL if failed.
   */
  private string get_source (Gs.App app) throws Error {
    var sources = app.get_sources ();
    if (sources.length != 1) {
      throw new Gs.PluginError.FAILED ("app %s has number of sources: %d != 1".printf (app.get_unique_id (), sources.length));
    }
    return sources[0];
  }

  public async override bool install_apps_async (Gs.AppList apps,
                                                 Gs.PluginInstallAppsFlags flags,
                                                 Gs.PluginProgressCallback progress_callback,
                                                 Gs.PluginEventCallback event_callback,
                                                 Gs.PluginAppNeedsUserActionCallback app_needs_user_action_callback,
                                                 GLib.Cancellable? cancellable) throws Error {
    /* So far, the apk server only allows donwloading and installing all-together
     * and we cannot really not download, or not apply the transaction */
    if ((flags &
         (Gs.PluginInstallAppsFlags.NO_DOWNLOAD
          | Gs.PluginInstallAppsFlags.NO_APPLY)) != 0) {
      throw new IOError.NOT_SUPPORTED ("Unsupported flags");
    }

    var add_list = new Gs.AppList ();

    // TODO: why not make this iterable
    for (int i = 0; i < apps.length (); i++) {
      var app = apps.index (i);

      /* enable repo, handled by dedicated function */
      assert (app.get_kind () != AppStream.ComponentKind.REPOSITORY);
      debug ("Considering app %s", app.get_unique_id ());

      /* We can only install apps we know of */
      if (!app.has_management_plugin (this)) {
        debug ("App %s is not managed by us, not installing", app.get_unique_id ());
        continue;
      }

      add_list.add (app);
      app.set_state (INSTALLING);
    }

    string[] source_array = {};
    for (int i = 0; i < add_list.length (); i++) {
      var app = add_list.index (i);
      var source = get_source (app);
      if (source != null) {
        source_array += source;
      }
    }

    try {
      yield proxy.call_add_packages (source_array, cancellable);
    } catch (Error local_error) {
      for (uint i = 0; i < add_list.length (); i++) {
        var app = add_list.index (i);
        app.set_state_recover ();
      }

      DBusError.strip_remote_error (local_error);
      throw local_error;
    }

    for (uint i = 0; i < add_list.length (); i++) {
      var app = add_list.index (i);
      app.set_state (INSTALLED);
    }

    return true;
  }

  public async override Gs.AppList list_apps_async (Gs.AppQuery query,
                                                    Gs.PluginListAppsFlags flags,
                                                    Gs.PluginEventCallback event_callback,
                                                    Cancellable? cancellable) throws Error {
    if (query == null) {
      throw new IOError.NOT_SUPPORTED ("Unsupported query");
    }

    var is_source = Gs.component_kind_array_contains (query.get_component_kinds (), AppStream.ComponentKind.REPOSITORY);
    var is_for_updates = query.get_is_for_update () == TRUE;

    /* Currently only support a subset of query properties, and only one set at once.
     * This is a pattern taken from upstream!
     */
    if (is_source == is_for_updates ||
        is_source == false ||
        is_for_updates == false) {
      throw new IOError.NOT_SUPPORTED ("Unsupported query");
    }

    if (is_source == true) {
      debug ("Listing repositories");

      unowned Variant out_repositories;

      try {
        yield proxy.call_list_repositories (cancellable, out out_repositories);
      } catch (Error local_error) {
        DBusError.strip_remote_error (local_error);
        throw local_error;
      }

      return list_repositories_cb (out_repositories);
    } else if (is_for_updates == true) {
      /* I believe we have to invalidate the cache here! */
      debug ("Listing updates");

      GLib.Variant upgradable_packages;
      var list = new Gs.AppList ();
      try {
        yield proxy.call_list_upgradable_packages (APK_POLKIT_CLIENT_DETAILS_FLAGS_ALL, cancellable, out upgradable_packages);
      } catch (Error local_error) {
        DBusError.strip_remote_error (local_error);
        throw local_error;
      }

      debug (@"Found $(upgradable_packages.n_children()) upgradable packages");

      foreach (var dict in upgradable_packages) {
        var pkg = ApkdPackage ();
        /* list_upgradable_packages doesn't have array input, thus no error output */
        if (!apk_variant_to_apkd (dict, ref pkg)) {
          assert_not_reached ();
        }

        if (pkg.packageState == Upgradable || pkg.packageState == Downgradable) {
          var app = apk_package_to_app (ref pkg);
          list.add (app);
        }
      }

      return list;
    } else {
      assert_not_reached ();
    }
  }

  private Gs.AppList list_repositories_cb (Variant repositories) throws Error {
    var list = new Gs.AppList ();

    foreach (var repository in repositories) {
      bool enabled;
      string description;
      string url;
      repository.get ("(bss)", out enabled, out description, out url);

      var app = cache_lookup (url);
      if (app != null) {
        app.set_state (enabled ? Gs.AppState.INSTALLED : Gs.AppState.AVAILABLE);
        list.add (app);
        continue;
      }

      debug ("Adding repository %s", url);

      string url_scheme;
      string url_path;
      Uri.split (url, GLib.UriFlags.NONE, out url_scheme, null, null, null, out url_path, null, null);

      /* Transform /some/repo/url into some.repo.url
         We are not allowed to use '/' in the app id. */
      var id = url_path.substring (1).replace ("/", ".");

      string repo_displayname;
      if (url_scheme != null) {
        /* If there is a scheme, it is a remote repository. Try to build
         * a description depending on the information available,
         * e.g: ["alpine", "edge", "community"] or ["postmarketos", "master"] */
        var repo_parts = id.split (".", 3);

        string repo = repo_parts[0];
        if (repo_parts.length == 3) {
          repo = "%s %s".printf (repo_parts[0], repo_parts[2]);
        }

        string release = "";
        if (repo_parts.length >= 2) {
          release = " (release %s)".printf (repo_parts[1]);
        }

        repo_displayname = _("Remote repository %s%s").printf (repo, release);
      } else {
        repo_displayname = _("Local repository %s").printf (url_path);
      }

      app = new Gs.App (id);
      app.set_kind (AppStream.ComponentKind.REPOSITORY);
      app.set_scope (AppStream.ComponentScope.SYSTEM);
      app.set_state (enabled ? Gs.AppState.INSTALLED : Gs.AppState.AVAILABLE);
      app.add_quirk (Gs.AppQuirk.NOT_LAUNCHABLE);
      app.set_name (Gs.AppQuality.UNKNOWN, repo_displayname);
      app.set_summary (Gs.AppQuality.UNKNOWN, description);
      app.set_url (AppStream.UrlKind.HOMEPAGE, url);
      app.set_metadata ("apk::repo-url", url);
      app.set_management_plugin (this);
      cache_add (url, app);
      list.add (app);
    }

    debug ("Added repositories");

    return list;
  }

  private void set_app_metadata (Gs.App app, ref ApkdPackage package) {
    if (package.version != null) {
      app.set_version (package.version);
    }
    if (package.description != null) {
      app.set_summary (Gs.AppQuality.UNKNOWN, package.description);
    }
    if (package.size != 0) {
      app.set_size_download (Gs.SizeType.VALID, package.size);
    }
    if (package.installedSize != 0) {
      app.set_size_installed (Gs.SizeType.VALID, package.installedSize);
    }
    if (package.url != null) {
      app.set_url (AppStream.UrlKind.HOMEPAGE, package.url);
    }
    if (package.license != null) {
      app.set_license (Gs.AppQuality.UNKNOWN, package.license);
    }

    debug ("State for pkg %s: %u", app.get_unique_id (), package.packageState);
    /* FIXME: Currently apk-rs-polkit only returns states Available and Installed
     * regardless of whether the packages are in a different state like upgraded.
     * If we blindly set the state of the app to the one from package, we will
     * in some circumstances overwrite the real state (that might have been).
     * Specially important for functions like gs_plugin_add_updates that only set
     * a temporary state. Therefore, here we only allow transitions which final
     * state is legally GS_APP_STATE_AVAILABLE or GS_APP_STATE_INSTALLED.
     */
    switch (app.get_state ()) {
    case UNKNOWN :
    case QUEUED_FOR_INSTALL :
    case REMOVING :
    case INSTALLING :
    case UNAVAILABLE:
      app.set_state (apk_to_app_state (package.packageState));
      break;
    case AVAILABLE:
    case INSTALLED:
      break; /* Ignore changes between the states */
    default:
      warning ("Wrong state transition detected and avoided!");
      break;
    }

    if (app.get_origin () == null)
      app.set_origin ("alpine");
    if (app.get_default_source () != package.name)
      app.add_source (package.name);
    app.set_management_plugin (this);
    app.set_bundle_kind (AppStream.BundleKind.PACKAGE);
  }

  public async override bool refine_async (Gs.AppList list,
                                           Gs.PluginRefineFlags flags,
                                           Gs.PluginRefineRequireFlags require_flags,
                                           Gs.PluginEventCallback event_callback,
                                           GLib.Cancellable? cancellable) throws Error {
    var missing_pkgname_list = new Gs.AppList ();
    var refine_apps_list = new Gs.AppList ();

    debug ("Starting refining process");

    for (uint i = 0; i < list.length (); i++) {
      var app = list.index (i);
      var bundle_kind = app.get_bundle_kind ();

      if (app.has_quirk (IS_WILDCARD) ||
          app.get_kind () == REPOSITORY) {
        debug ("App %s has quirk WILDCARD or is a repository; not refining!", app.get_unique_id ());
        continue;
      }

      /* Only package and unknown (desktop or metainfo file with upstream AS)
       * belong to us */
      if (bundle_kind != UNKNOWN &&
          bundle_kind != PACKAGE) {
        debug ("App %s has bundle kind %s; not refining!", app.get_unique_id (), bundle_kind.to_string ());
        continue;
      }

      /* set management plugin for system apps just created by appstream */
      if (app.has_management_plugin (null) &&
          app.get_scope () == SYSTEM &&
          app.get_metadata_item ("GnomeSoftware::Creator") == "appstream") {
        /* If appstream couldn't assign a source, it means the app does not
         * have an entry in the distribution-generated metadata. That should
         * be fixed in the app. We try to workaround it by finding the
         * owner of the metainfo or desktop file */
        if (app.get_default_source () == null) {
          debug ("App %s missing pkgname. Will try to resolve via metainfo/desktop file", app.get_unique_id ());
          missing_pkgname_list.add (app);
          continue;
        }

        debug ("Setting ourselves as management plugin for app %s", app.get_unique_id ());
        app.set_management_plugin (this);
      }

      if (!app.has_management_plugin (this)) {
        debug ("Ignoring app %s, not owned by apk", app.get_unique_id ());
        continue;
      }

      var sources = app.get_sources ();
      if (sources.length == 0) {
        warning ("app %s has missing sources; skipping", app.get_unique_id ());
        continue;
      }
      if (sources.length >= 2) {
        warning ("app %s has %d > 1 sources; skipping", app.get_unique_id (), sources.length);
        continue;
      }

      /* If we reached here, the app is valid and under our responsibility.
         Therefore, we have to make sure that it stays valid. For that purpose,
         if the state is unknown, force refining by setting the SETUP_ACTION
         flag. This has the drawback that it forces a refine for all other apps.
         The alternative would be to have yet another app list. But since this
         is expected to happen very seldomly, it should be fine */
      if (app.get_state () == UNKNOWN) {
        require_flags |= SETUP_ACTION;
      }

      debug ("Selecting app %s for refine", app.get_unique_id ());
      refine_apps_list.add (app);
    }

    try {
      yield fix_app_missing_appstream_async (missing_pkgname_list, cancellable);
    } catch (Error local_error) {
      // TODO: We should print a warning, but continue execution!
      // There's no reason failing to find some package should stop
      // the rest of the processing.
      throw local_error;
    }

    yield refine_apk_packages_cb (refine_apps_list, missing_pkgname_list, flags, require_flags, cancellable);

    return true;
  }

  /**
   * fix_app_missing_appstream:
   * @plugin: The apk GsPlugin.
   * @list: The GsAppList to resolve the metainfo/desktop files for.
   * @cancellable: GCancellable to cancel synchronous dbus call.
   * @task: FIXME!
   *
   * If the appstream plugin could not find the apps in the distribution metadata,
   * it might have created the application from the metainfo or desktop files
   * installed. It will contain some basic information, but the apk package to
   * which it belongs (the source) needs to completed by us.
   **/
  private async bool fix_app_missing_appstream_async (Gs.AppList list,
                                                      Cancellable? cancellable) throws Error {
    if (list.length () == 0) {
      return true;
    }

    debug ("Trying to find source packages for %u apps", list.length ());

    var search_list = new Gs.AppList ();
    string[] fn_array = {};

    /* The appstream plugin sets some metadata on apps that come from desktop
     * and metainfo files. If metadata is missing, just give-up */
    for (int i = 0; i < list.length (); i++) {
      var app = list.index (i);
      var source_file = app.get_metadata_item ("appstream::source-file");
      if (source_file != null) {
        search_list.add (app);
        fn_array += source_file;
      } else {
        warning ("Couldn't find 'appstream::source-file' metadata for %s", app.get_unique_id ());
      }
    }

    if (fn_array.length == 0)
      return true;

    GLib.Variant search_results;

    yield proxy.call_search_files_owners (fn_array, ApkPolkit2.DetailsFlags.NONE, cancellable, out search_results);

    yield search_file_owners_cb (search_results, search_list, fn_array);

    return true;
  }

  private async bool search_file_owners_cb (Variant search_results, Gs.AppList search_list, string[] fn_array) {
    assert (search_results.n_children () == search_list.length ());
    for (int i = 0; i < search_list.length (); i++) {
      var app = search_list.index (i);
      var apk_pkg = ApkdPackage ();

      var apk_pkg_variant = search_results.get_child_value (i);
      if (!apk_variant_to_apkd (apk_pkg_variant, ref apk_pkg)) {
        warning ("Couldn't find any package owning file '%s'", fn_array[i]);
        continue;
      }

      debug ("Found pkgname '%s' for app %s: adding source and setting management plugin", apk_pkg.name, app.get_unique_id ());
      app.add_source (apk_pkg.name);
      app.set_management_plugin (this);
    }

    return true;
  }

  private async bool refine_apk_packages_cb (Gs.AppList list,
                                             Gs.AppList missing_pkgname_list,
                                             Gs.PluginRefineFlags flags,
                                             Gs.PluginRefineRequireFlags require_flags,
                                             Cancellable? cancellable) throws Error {
    if ((require_flags
         & (Gs.PluginRefineRequireFlags.VERSION
            | Gs.PluginRefineRequireFlags.ORIGIN
            | Gs.PluginRefineRequireFlags.DESCRIPTION
            | Gs.PluginRefineRequireFlags.SETUP_ACTION
            | Gs.PluginRefineRequireFlags.SIZE
            | Gs.PluginRefineRequireFlags.URL
            | Gs.PluginRefineRequireFlags.LICENSE
         )) == 0
    ) {
      debug ("Ignoring refine");
      return true;
    }

    for (int i = 0; i < missing_pkgname_list.length (); i++) {
      var app = missing_pkgname_list.index (i);
      if (app.get_default_source () != null) {
        list.add (app);
      }
    }

    if (list.length () == 0) {
      return true;
    }

    var details_flags = ApkPolkit2.DetailsFlags.PACKAGE_STATE;

    if ((require_flags & Gs.PluginRefineRequireFlags.SETUP_ACTION) != 0) {
      details_flags |= APK_POLKIT_CLIENT_DETAILS_FLAGS_ALL;
    }
    if ((require_flags & Gs.PluginRefineRequireFlags.VERSION) != 0) {
      details_flags |= VERSION;
    }
    if ((require_flags & Gs.PluginRefineRequireFlags.DESCRIPTION) != 0) {
      details_flags |= DESCRIPTION;
    }
    if ((require_flags & Gs.PluginRefineRequireFlags.SIZE) != 0) {
      details_flags |= SIZE | INSTALLED_SIZE;
    }
    if ((require_flags & Gs.PluginRefineRequireFlags.URL) != 0) {
      details_flags |= URL;
    }
    if ((require_flags & Gs.PluginRefineRequireFlags.LICENSE) != 0) {
      details_flags |= LICENSE;
    }

    string[] source_array = new string[list.length ()];
    for (int i = 0; i < list.length (); i++) {
      var app = list.index (i);
      debug ("Requesting details for %s", app.get_unique_id ());
      source_array[i] = app.get_default_source ();
    }

    GLib.Variant apk_pkgs;

    yield proxy.call_get_packages_details (source_array, details_flags, cancellable, out apk_pkgs);

    return yield get_packages_details_cb (list, apk_pkgs);
  }

  private async bool get_packages_details_cb (Gs.AppList list, Variant apk_pkgs) {
    assert (list.length () == apk_pkgs.n_children ());
    for (int i = 0; i < list.length (); i++) {
      var app = list.index (i);

      debug ("Refining %s", app.get_unique_id ());
      var apk_pkg_variant = apk_pkgs.get_child_value (i);
      var apk_pkg = ApkdPackage ();

      var source = app.get_default_source ();
      if (!apk_variant_to_apkd (apk_pkg_variant, ref apk_pkg)) {
        if (source != apk_pkg.name)
          warning ("source: '%s' and the pkg name: '%s' differ", source, apk_pkg.name);
        continue;
      }

      if (source != apk_pkg.name) {
        warning ("source: '%s' and the pkg name: '%s' differ", source, apk_pkg.name);
        continue;
      }

      set_app_metadata (app, ref apk_pkg);
      /* We should only set generic apps for OS updates */
      if (app.get_kind () == AppStream.ComponentKind.GENERIC) {
        app.set_special_kind (Gs.AppSpecialKind.OS_UPDATE);
      }
    }

    return true;
  }

  public async override bool launch_async (Gs.App app,
                                           Gs.PluginLaunchFlags flags,
                                           GLib.Cancellable? cancellable) throws Error {
    return yield app_launch_filtered_async (app, flags, filter_desktop_file_cb, cancellable);
  }

  private bool filter_desktop_file_cb (Gs.Plugin plugin,
                                       Gs.App app,
                                       string filename,
                                       GLib.KeyFile key_file) {
    return !filename.contains ("/snapd/") &&
           !filename.contains ("/snap/") &&
           !filename.contains ("/flatpak/") &&
           key_file.has_group ("Desktop Entry") &&
           !key_file.has_key ("Desktop Entry", "X-Flatpak") &&
           !key_file.has_key ("Desktop Entry", "X-SnapInstanceName");
  }

  /**
   * gs_plugin_apk_prepare_update:
   * @plugin: The apk plugin
   * @list: List of desired apps to update
   * @ready: List to store apps once ready to be updated
   *
   * Convenience function which takes a list of apps to update and
   * a list to store apps once they are ready to be updated. It iterate
   * over the apps from @list, takes care that it is possible to update them,
   * and when they are ready to be updated, adds them to @ready.
   *
   * Returns: Number of non-proxy apps added to the list
   **/
  private uint prepare_update (Gs.AppList list,
                               ref Gs.AppList ready) {
    uint added = 0;

    for (uint i = 0; i < list.length (); i++) {
      var app = list.index (i);

      /* We shall only touch the apps if they are are owned by us or
       * a proxy (and thus might contain some apps owned by us) */
      if (app.has_quirk (IS_PROXY)) {
        var proxy_added = prepare_update (app.get_related (), ref ready);
        if (proxy_added > 0) {
          app.set_state (INSTALLING);
          ready.add (app);
          added += proxy_added;
        }
        continue;
      }

      if (!app.has_management_plugin (this)) {
        debug ("Ignoring update on '%s', not owned by APK", app.get_unique_id ());
        continue;
      }

      app.set_state (INSTALLING);
      ready.add (app);
      added++;
    }

    return added;
  }

  public async override bool update_apps_async (Gs.AppList apps,
                                                Gs.PluginUpdateAppsFlags flags,
                                                Gs.PluginProgressCallback progress_callback,
                                                Gs.PluginEventCallback event_callback,
                                                Gs.PluginAppNeedsUserActionCallback app_needs_user_action_callback,
                                                GLib.Cancellable? cancellable) throws Error {
    debug ("Updating apps");

    if ((flags & Gs.PluginUpdateAppsFlags.NO_DOWNLOAD) == 0) {
      // This needs polkit changes. Ideally we'd download first, and
      // apply from cache then. We should probably test this out in
      // pmOS release upgrader script first
      warning ("We don't implement 'NO_DOWNLOAD'");
    }

    if ((flags & Gs.PluginUpdateAppsFlags.NO_APPLY) != 0) {
      return true;
    }

    var list_installing = new Gs.AppList ();

    var num_sources = prepare_update (apps, ref list_installing);

    debug ("Found %u apps to update", num_sources);

    if (num_sources == 0) {
      return true;
    }

    string[] source_array = {};
    for (var i = 0; i < num_sources; i++) {
      var app = list_installing.index (i);
      var source = app.get_default_source ();
      if (source != null) {
        source_array += source;
        app.set_state (Gs.AppState.DOWNLOADING);
      }
    }

    try {
      yield proxy.call_upgrade_packages (source_array, cancellable);
    } catch (Error local_error) {
      /* When and upgrade transaction failed, it could be out of two reasons:
       * - The world constraints couldn't match. In that case, nothing was
       * updated and we are safe to set all the apps to the recover state.
       * - Actual errors happened! Could be a variety of things, including
       * network timeouts, errors in packages' ownership and what not. This
       * is dangerous, since the transaction was run half-way. Show an error
       * that the user should run `apk fix` and that the system might be in
       * an inconsistent state. We also have no idea of which apps succeded
       * and which didn't, so also recover everything and hope the refine
       * takes care of fixing things in the aftermath. */
      DBusError.strip_remote_error (local_error);
      for (uint i = 0; i < list_installing.length (); i++) {
        var app = list_installing.index (i);
        app.set_state_recover ();
      }

      message ("updating failed %s", local_error.message);

      throw local_error;
    }

    for (uint i = 0; i < list_installing.length (); i++) {
      var app = list_installing.index (i);
      app.set_state (INSTALLED);
    }

    debug ("All apps updated correctly");

    updates_changed ();
    return true;
  }

  public async override bool uninstall_apps_async (Gs.AppList list,
                                                   Gs.PluginUninstallAppsFlags flags,
                                                   Gs.PluginProgressCallback progress_callback,
                                                   Gs.PluginEventCallback event_callback,
                                                   Gs.PluginAppNeedsUserActionCallback app_needs_user_action_callback,
                                                   GLib.Cancellable? cancellable) throws GLib.Error {

    var del_list = new Gs.AppList ();

    for (var i = 0; i < list.length (); i++) {
      var app = list.index (i);

      /* disable repo, handled by dedicated function */
      assert (app.get_kind () != AppStream.ComponentKind.REPOSITORY);
      debug ("Considering app %s for uninstallation", app.get_unique_id ());

      /* We can only remove apps we know of */
      if (!app.has_management_plugin (this)) {
        debug ("App %s is not managed by us, not uninstalling", app.get_unique_id ());
        continue;
      }

      del_list.add (app);
      app.set_state (REMOVING);
    }

    string[] source_array = {};
    for (var i = 0; i < del_list.length (); i++) {
      var app = del_list.index (i);
      var source = app.get_default_source ();
      if (source != null) {
        source_array += source;
      }
    }

    try {
      yield proxy.call_delete_packages (source_array, cancellable);
    } catch (Error local_error) {
      for (uint i = 0; i < del_list.length (); i++) {
        var app = del_list.index (i);
        app.set_state_recover ();
      }

      DBusError.strip_remote_error (local_error);
      throw local_error;
    }

    for (uint i = 0; i < del_list.length (); i++) {
      var app = del_list.index (i);
      app.set_state (AVAILABLE);
    }

    return true;
  }

  public async override bool install_repository_async (Gs.App repo,
                                                       Gs.PluginManageRepositoryFlags flags,
                                                       Gs.PluginEventCallback event_callback,
                                                       GLib.Cancellable? cancellable) throws Error {
    assert (repo.get_kind () == AppStream.ComponentKind.REPOSITORY);

    repo.set_state (INSTALLING);

    return yield repo_update (repo, true, cancellable);
  }

  public async override bool remove_repository_async (Gs.App repo,
                                                      Gs.PluginManageRepositoryFlags flags,
                                                      Gs.PluginEventCallback event_callback,
                                                      GLib.Cancellable? cancellable) throws Error {
    assert (repo.get_kind () == AppStream.ComponentKind.REPOSITORY);

    repo.set_state (REMOVING);

    return yield repo_update (repo, false, cancellable);
  }

  private async bool repo_update (Gs.App repo,
                                  bool is_install,
                                  GLib.Cancellable? cancellable) throws Error {
    string action = is_install ? "Install" : "Remov";

    if (!repo.has_management_plugin (this)) {
      return true;
    }

    repo.set_progress (GS_APP_PROGRESS_UNKNOWN);

    var url = repo.get_metadata_item ("apk::repo-url");
    debug ("%ssing repository %s", action, url);

    try {
      if (is_install) {
        yield proxy.call_add_repository (url, cancellable);

        debug ("Installed repository %s", url);
        repo.set_state (INSTALLED);
      } else {
        yield proxy.call_remove_repository (url, cancellable);

        debug ("Removed repository %s", url);
        repo.set_state (AVAILABLE);
      }
    } catch (Error local_error) {
      repo.set_state_recover ();
      DBusError.strip_remote_error (local_error);
      throw local_error;
    }

    return true;
  }
}

// TODO: find way to move this to the class
public static void gs_plugin_adopt_app (Gs.Plugin self, Gs.App app) {
  debug ("App to adopt: %s", app.get_id ());

  if (app.get_bundle_kind () == AppStream.BundleKind.PACKAGE &&
      app.get_scope () == AppStream.ComponentScope.SYSTEM) {
    app.set_management_plugin (self);
  }

  if (app.get_kind () == AppStream.ComponentKind.OPERATING_SYSTEM) {
    app.set_management_plugin (self);
  }
}

// TODO: find a way to move this to the class
public static Type gs_plugin_query_type () {
  return typeof (GsPluginApk2);
}
