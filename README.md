# gnome-software-plugin-apk2

> [!CAUTION]
> This plugin is incomplete, experimental and unstable. Use at own your risk.

This is a plugin that allows users to update their systems using GNOME Software.

It's a rewrite of the unmantained [gnome-software-plugin-apk] in Vala.

## Hacking

Building the app is currently fairly complex, partly due to some [Meson issues][meson-issue], and partly due to my skill issues.

### 1. Install Dependencies

Using my `APKBUILD`s for [GNOME Software v48][gnome-software-apkbuild] and the [latest apk-polkit-rs][apk-polkit-rs-apkbuild] is probably the easiest way.

Then do:

```sh
apk install -t .gs-plugin-apk2 gnome-software-dev gnome-software-dbg apk-polkit-rs-dev apk-polkit-rs-dbg meson ninja
```

Then make sure the `apk-polkit-server` is running

```sh
service apk-polkit-server start
```

### 2. Build the library

```sh
meson setup build

cd build
# please input these line by line (you only need to do this once)
ninja src/vapi/Gs-49.gir
ninja src/vapi/ApkPolkit2-0.gir
ninja src/vapi/gnome-software.vapi
ninja src/vapi/apk-polkit-client-2.vapi
ninja
```

### 3. Install the library

```sh
ninja install
```

> PS: you can later uninstall by doing `ninja uninstall`

### 4. Run GNOME Software with the plugin loaded

```sh
gnome-software --quit && gnome-software
```

## Resources

- [gnome-software] : https://gitlab.gnome.org/GNOME/gnome-software
- [apk-polkit-rs] : https://gitlab.alpinelinux.org/Cogitri/apk-polkit-rs

[apk-polkit-rs]: https://gitlab.alpinelinux.org/Cogitri/apk-polkit-rs
[gnome-software]: https://gitlab.gnome.org/GNOME/gnome-software
[gnome-software-plugin-apk]: https://github.com/Cogitri/gnome-software-plugin-apk
[meson-issue]: https://github.com/mesonbuild/meson/issues/12849
[gnome-software-apkbuild]: https://github.com/vixalien/myports/tree/main/gnome-software
[apk-polkit-rs-apkbuild]: https://github.com/vixalien/myports/tree/main/apk-polkit-rs
