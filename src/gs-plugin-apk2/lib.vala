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
  private void* proxy;

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
  private bool apk_variant_to_apkd(Variant dict, ApkdPackage pkg) {
    string error_str;
    if (!dict.lookup("name", "&s", out pkg.name)) {
      return false;
    }
    if (dict.lookup("error", "&s", out error_str)) {
      warning(@"Package $(pkg.name) could not be unpacked: $error_str");
      return false;
    }

    dict.lookup("version", "&s", out pkg.version);
    dict.lookup("description", "&s", out pkg.description);
    dict.lookup("license", "&s", out pkg.license);
    dict.lookup("url", "&s", out pkg.url);
    dict.lookup("staging_version", "&s", out pkg.stagingVersion);
    dict.lookup("installed_size", "t", out pkg.installedSize);
    dict.lookup("size", "t", out pkg.size);
    dict.lookup("package_state", "u", out pkg.packageState);

    return true;
  }

  /**
   * apk_to_app_state:
   * @state: A ApkPackageState
   *
   * Convenience function which converts ApkdPackageState to a GsAppState.
   **/
  private Gs.AppState apk_to_app_state(ApkPackageState state) {
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
      assert_not_reached();
      return Gs.AppState.UNKNOWN;
    }
  }

  /**
   * apk_package_to_app:
   * @pkg: A ApkPackage
   *
   * Convenience function which converts a ApkdPackage to a GsApp.
   **/
  private Gs.App apk_package_to_app(Gs.Plugin plugin, ApkdPackage pkg) {
    string cache_name = "%s-%s".printf(pkg.name, pkg.version);
    // Gs.App app = plugin.cache_lookup(cache_name);
    Gs.App app = null;

    if (app != null) {
      return app;
    }

    app = new Gs.App(pkg.name);

    app.set_kind(AppStream.ComponentKind.GENERIC);
    app.set_bundle_kind(AppStream.BundleKind.PACKAGE);
    app.set_scope(AppStream.ComponentScope.SYSTEM);
    app.set_allow_cancel(false);
    app.add_source(pkg.name);
    app.set_name(Gs.AppQuality.UNKNOWN, pkg.name);
    app.set_kind(AppStream.ComponentKind.GENERIC);
    app.set_kind(AppStream.ComponentKind.GENERIC);
    app.set_kind(AppStream.ComponentKind.GENERIC);
    app.set_kind(AppStream.ComponentKind.GENERIC);
    app.set_kind(AppStream.ComponentKind.GENERIC);
    app.set_kind(AppStream.ComponentKind.GENERIC);
    app.set_kind(AppStream.ComponentKind.GENERIC);

    return app;
  }
}
