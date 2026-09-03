# App icon

`app_icon.svg` is the app's mark — the same tile and glyph that
[`BrandMark`](../../lib/ui/widgets/brand_mark.dart) draws in the top-left of the
main screen, at its native 32pt with the light theme's colours. Its geometry is
read off `ThemeRepo`: an 8pt inset, a 16pt glyph, and a 7.8 corner radius
(`radius` 0.65 × 12). The glyph is Lucide's `chart-no-axes-column`, taken from
the outline shadcn_flutter ships in `icons/lucide/lucide.symbol.svg`, so it is
the same shape the icon font renders rather than a redrawing of it.

`app_icon_macos.svg` composes that mark onto Apple's macOS icon grid: an 824×824
body centred in a 1024 canvas with the platform's 185.4 corner radius, so the
tile reads the same size as its neighbours in the Dock. `app_icon_macos.png` is
its 1024×1024 export and is what `flutter_launcher_icons` reads.

## Regenerating

After editing either SVG, re-export the PNG and rebuild the icon set:

```sh
rsvg-convert -w 1024 -h 1024 assets/icon/app_icon_macos.svg -o assets/icon/app_icon_macos.png
fvm dart run flutter_launcher_icons
```

That rewrites `macos/Runner/Assets.xcassets/AppIcon.appiconset/`. Any SVG
rasteriser will do; `rsvg-convert` comes from Homebrew's `librsvg`.
