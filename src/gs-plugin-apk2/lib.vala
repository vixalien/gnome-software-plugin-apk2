public const uint APK_POLKIT_CLIENT_DETAILS_FLAGS_ALL = 0xFF;

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
  private ApkPolkit2.Proxy proxy;

  construct {
    add_rule (Gs.PluginRule.RUN_BEFORE, "icons");
    add_rule (Gs.PluginRule.RUN_BEFORE, "generic-updates");
    /* We want to get packages from appstream and refine them */
    add_rule (Gs.PluginRule.RUN_BEFORE, "appstream");

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
  private bool apk_variant_to_apkd (Variant dict, ApkdPackage pkg) {
    string error_str;
    if (!dict.lookup ("name", "&s", out pkg.name)) {
      return false;
    }
    if (dict.lookup ("error", "&s", out error_str)) {
      warning (@"Package $(pkg.name) could not be unpacked: $error_str");
      return false;
    }

    dict.lookup ("version", "&s", out pkg.version);
    dict.lookup ("description", "&s", out pkg.description);
    dict.lookup ("license", "&s", out pkg.license);
    dict.lookup ("url", "&s", out pkg.url);
    dict.lookup ("staging_version", "&s", out pkg.stagingVersion);
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
  private Gs.App apk_package_to_app (ApkdPackage pkg) {
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
      proxy = yield new ApkPolkit2.Proxy.for_connection (this.get_system_bus_connection (),
                                                         DBusProxyFlags.NONE,
                                                         "dev.Cogitri.apkPolkit2",
                                                         "/dev/Cogitri/apkPolkit2",
                                                         cancellable
      );
    } catch (Error local_error) {
      DBusError.strip_remote_error (local_error);
      throw local_error;
    }

    proxy.set_default_timeout (int.MAX);

    return true;
  }

  public async override Gs.AppList list_apps_async (Gs.AppQuery query,
                                                    Gs.PluginListAppsFlags flags,
                                                    Cancellable? cancellable) throws Error {
    if (query == null ||
        query.get_keywords () == null ||
        query.get_n_properties_set () != 1) {
      throw new IOError.NOT_SUPPORTED ("Unsupported query");
    }

    var is_source = query.get_is_source ();
    var is_for_updates = query.get_is_for_update ();

    /* Currently only support a subset of query properties, and only one set at once.
     * This is a pattern taken from upstream!
     */
    if (is_source == is_for_updates ||
        is_source == FALSE ||
        is_for_updates == FALSE) {
      throw new IOError.NOT_SUPPORTED ("Unsupported query");
    }

    if (is_source == TRUE) {
      debug ("Listing repositories");

      unowned Variant out_repositories;

      try {
        yield proxy.call_list_repositories (cancellable, out out_repositories);
      } catch (Error local_error) {
        DBusError.strip_remote_error (local_error);
        throw local_error;
      }

      return list_repositories_cb (out_repositories);
    } else if (is_for_updates == TRUE) {
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

      debug (@"Found $(upgradable_packages.n_children())");

      foreach (var dict in upgradable_packages) {
        var pkg = ApkdPackage () {
          packageState = Available
        };
        /* list_upgradable_packages doesn't have array input, thus no error output */
        if (!apk_variant_to_apkd (dict, pkg)) {
          assert_not_reached ();
        }

        if (pkg.packageState == Upgradable || pkg.packageState == Downgradable) {
          var app = apk_package_to_app (pkg);
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
}

public static Type gs_plugin_query_type () {
  return typeof (GsPluginApk2);
}
