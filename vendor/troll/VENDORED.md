# Vendored: troll

Source: https://github.com/sonnyp/troll
Pinned commit: `37b53b29db0b6496f31e13c7f843100db31c9eb1` (the exact sha
`origin/main`'s `.gitmodules`/gitlink for `troll` names).

Vendored here, rather than left as an unresolvable gitlink, so that
`lib/theme_selector.rb` and `lib/window_state.rb` can be diffed against the
upstream source they were ported from:

- `lib/theme_selector.rb` ported from `src/widgets/ThemeSelector.{js,blp,css}`
- `lib/window_state.rb` ported from `src/util.js` (`persistWindowState`)

`node_modules/` and `.git/` are excluded; everything else in the pinned
commit's tree is present unmodified.
