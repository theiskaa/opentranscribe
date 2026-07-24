# liquid

Flutter plugin that exposes native iOS Liquid Glass components through platform views. Widgets provide a declarative, Flutter-first API while rendering true native controls on iOS 26+. On every other platform, and on iOS below 26, each widget renders nothing (`SizedBox.shrink()`), so a caller has to gate on the platform and supply its own fallback.

> Vendored into this repo from a package by [@suxoikorm](https://github.com/suxoikorm), under the LICENSE beside this file. In opentranscribe the gate is `PlatformCaps.nativeGlass` and the fallbacks are `AppIconButton` and `showAppMenu`.
