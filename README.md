### Compile GIR for GNOME Software

```sh
g-ir-scanner \
  -n GnomeSoftware \
  --library /usr/lib/gnome-software/libgnomesoftware.so.20 \
  -DI_KNOW_THE_GNOME_SOFTWARE_API_IS_SUBJECT_TO_CHANGE=1 \
  -I /usr/include/gnome-software \
  /usr/include/gnome-software/gnome-software.h
```

again

```sh
FILES=
g-ir-scanner \
  --warn-all \
  --include AppStream-1.0 \
  --include Gdk-4.0 \
  --include Soup-3.0 \
  --namespace GsApp \
  --identifier-prefix Gs \
  --symbol-prefix gs \
  --pkg gnome-software \
  --pkg appstream \
  --library-path /usr/lib/gnome-software \
  --library /usr/lib/gnome-software/libgnomesoftware.so.20 \
  -DI_KNOW_THE_GNOME_SOFTWARE_API_IS_SUBJECT_TO_CHANGE=1 \
  /usr/include/gnome-software/gnome-software.h \
  $(
    grep -o '#include <[^>]*>' \
      /usr/include/gnome-software/gnome-software.h | \
      sed 's/#include <\(.*\)>/\/usr\/include\/gnome-software\/\1/'
  )
```
