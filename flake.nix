{
  description = "Biblioteca — a Ruby GTK4 port";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Shared libraries every ruby-gnome extension links against.
        gtkStack = with pkgs; [
          glib
          gobject-introspection
          cairo
          pango
          gdk-pixbuf
          graphene
          atk
          gtk4
          libadwaita
          # WebKitGTK 6.0 — the webkit-gtk gem's typelib and shared library.
          webkitgtk_6_0
          harfbuzz
          librsvg
          # The libspelling gem's typelib and shared library.
          libspelling
        ]
        # The Ruby `pkg-config` gem resolves `Requires.private` transitively and
        # hard-fails if any .pc in the chain is missing, so gtk4's whole private
        # closure has to be on PKG_CONFIG_PATH, not just its public deps.
        ++ (with pkgs; [
          fontconfig
          freetype
          libepoxy
          libpng
          libxkbcommon
          pcre2
          util-linux
          wayland
          zlib
          fribidi
          libdatrie
          libthai
          libselinux
          libsepol
          expat
          brotli
          bzip2
          graphite2
          icu
          libffi
          libxml2
          lerc
          libdeflate
          xz
          zstd
        ])
        # Un-prefixed names: the `xorg.*` package set is deprecated.
        ++ (with pkgs; [
          libx11
          libxau
          libxcursor
          libxdmcp
          libxext
          libxfixes
          libxi
          libxinerama
          libxrandr
          libxrender
          libxcb
          xorgproto
        ]);

        # ruby-gnome gems build C extensions with extconf.rb + the pkg-config
        # gem; nixpkgs only ships gemConfig entries for the GTK3-era subset, so
        # the GTK4 gems get their build inputs declared here.
        rubyGnomeGem = _attrs: {
          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = gtkStack;
        };

        gemConfig = pkgs.defaultGemConfig // {
          gdk4 = rubyGnomeGem;
          gsk4 = rubyGnomeGem;
          gtk4 = rubyGnomeGem;
          graphene1 = rubyGnomeGem;
          adwaita = rubyGnomeGem;
          webkit-gtk = rubyGnomeGem;
          rsvg2 = rubyGnomeGem;
        };

        # `makeSearchPath` would take each package's *first* output, and glib's
        # first output is `bin`, which carries no typelibs — hence the explicit
        # `.out`. at-spi2-core is here for the Atk typelib.
        typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
          (map (drv: drv.out or drv) (gtkStack ++ [ pkgs.at-spi2-core ]));

        # ashpd carries a Rust extension, and its precompiled platform gems need no
        # compiler. Gemfile.lock names every platform the gem ships, so bundix writes
        # the one entry it always writes: no platform, and the source gem's hash --
        # which would want cargo to build it, and fails here as
        #   hash mismatch in fixed-output derivation 'ashpd-0.1.1.gem.drv'
        # because the fetch gets a platform gem and the lock recorded the source one.
        #
        # The platform belongs to the system being built for rather than to the
        # lockfile, so the entry is rewritten into the platform gem for this system.
        # This is the pattern gnome-maps-rb uses for the same gem.
        #
        # These hashes are for the version Gemfile.lock resolves: a bump needs them
        # recomputed with
        #   nix-prefetch-url https://rubygems.org/downloads/ashpd-<v>-<platform>.gem
        ashpdPlatforms = {
          x86_64-linux  = { platform = "x86_64-linux";  sha256 = "0pnjv2rszvd10dvn3qmgf5vlkgmkjnkj18phvbvaya1arsm3ph9s"; };
          aarch64-linux = { platform = "aarch64-linux"; sha256 = "156x0l8fal0n05k6ya6qdfgl8277595mrg6gx0syis6dx3rr8fk7"; };
          x86_64-darwin = { platform = "x86_64-darwin"; sha256 = "0dq81l7pkmxpkxp9i6g3wwdj9pynp4jl691sw8d6q58qww5a2ag8"; };
          aarch64-darwin = { platform = "arm64-darwin"; sha256 = "19xfp65ag0mmp55kkwwq9qg0vmm1pxfswf9qca55b81k9phw2bbq"; };
        };

        bibliotecaGemset = import ./nix/gemset.nix;

        ashpdGem =
          let
            selected = ashpdPlatforms.${system} or (throw
              "ashpd has no precompiled gem for ${system}");
            generic = bibliotecaGemset.ashpd;
          in
          generic // {
            version = "${generic.version}-${selected.platform}";
            source = generic.source // { sha256 = selected.sha256; };
          };

        # nix/ and not the repo root: the root Gemfile is kettle-jem's
        # development bundle — rubocop, rspec, yard, the kettle-dev stack — and
        # must not end up in a packaged app's runtime closure. nix/Gemfile holds
        # the gemspec's runtime dependencies only.
        gems = pkgs.bundlerEnv {
          name = "Biblioteca-gems";
          ruby = pkgs.ruby_3_4;
          inherit gemConfig;
          # gemfile/lockfile/gemset explicitly rather than `gemdir`, because the
          # gemset is patched above to select ashpd's platform gem; gemdir would
          # read nix/gemset.nix unmodified and fetch the source gem.
          gemfile = ./nix/Gemfile;
          lockfile = ./nix/Gemfile.lock;
          gemset = bibliotecaGemset // { ashpd = ashpdGem; };
        };

        # The launcher is whatever the gemspec installs into exe/. Reading the
        # directory keeps this flake generic: no name to keep in step by hand.
        launcher = builtins.head (builtins.attrNames (builtins.readDir ./exe));

        # Optional directories: a port that has not grown translations or data
        # assets yet simply has none.
        optionalDirs = builtins.filter (d: builtins.pathExists (./. + "/${d}")) [
          "data"
          "po"
        ];
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "Biblioteca";
          version = "0.1.0";
          src = ./.;

          # Deliberately no wrapGAppsHook4: glib's setup hook relocates
          # share/glib-2.0/schemas during fixup, after wrapGAppsHook4 has
          # computed its wrapper arguments, so a schema would end up somewhere
          # the wrapper never looks. The wrapper below is built by hand and
          # points at both the pre- and post-move paths.
          nativeBuildInputs = [ pkgs.makeWrapper ];
          buildInputs = [ gems ] ++ gtkStack;

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/Biblioteca
            cp -r lib $out/share/Biblioteca/
            for d in ${pkgs.lib.escapeShellArgs optionalDirs}; do
              cp -r "$d" $out/share/Biblioteca/
            done
            # exe/ sits next to lib/ so the launcher's `require "Biblioteca"`
            # resolves against the copied tree.
            install -Dm755 exe/${launcher} $out/share/Biblioteca/exe/${launcher}

            # Compile the GSettings schema the port ships. Unconditional, not
            # gated on a pre-existing data/schemas — that directory is only
            # ever produced by a developer running `rake schema:compile` by
            # hand, and a build that skips it silently ships no compiled
            # schema at all, which is what made the schema only reachable
            # after that manual step. The source of truth is
            # data/app.gschema.xml, which is always in the tree.
            mkdir -p $out/share/glib-2.0/schemas
            cp data/app.gschema.xml $out/share/glib-2.0/schemas/org.rubygtkproject.Biblioteca.gschema.xml
            ${pkgs.glib.dev}/bin/glib-compile-schemas $out/share/glib-2.0/schemas

            # -rbundler/setup puts the bundled gems on the load path, and
            # GI_TYPELIB_PATH keeps GObject-Introspection from re-registering
            # types the cairo gem's C extension has already registered.
            makeWrapper ${gems.wrappedRuby}/bin/ruby $out/bin/${launcher} \
              --add-flags "-rbundler/setup" \
              --add-flags "-I$out/share/Biblioteca/lib" \
              --add-flags "$out/share/Biblioteca/exe/${launcher}" \
              --set GI_TYPELIB_PATH "${typelibPath}" \
              --prefix XDG_DATA_DIRS : "$out/share" \
              --prefix XDG_DATA_DIRS : "$out/share/gsettings-schemas/Biblioteca-0.1.0" \
              --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}" \
              --prefix XDG_DATA_DIRS : "${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}" \
              --prefix XDG_DATA_DIRS : "${pkgs.adwaita-icon-theme}/share"

            runHook postInstall
          '';

          meta = {
            description = "A Ruby GTK4 / Libadwaita port of Biblioteca";
            mainProgram = launcher;
            platforms = pkgs.lib.platforms.linux;
          };
        };

        apps.default = utils.lib.mkApp { drv = self.packages.${system}.default; };

        devShells.default = pkgs.mkShell {
          name = "Biblioteca-devshell";

          packages = [
            gems
            gems.wrappedRuby
            pkgs.bundler
            pkgs.bundix
            pkgs.pkg-config
            pkgs.glib.dev
            pkgs.gettext
            # rxgettext, the extractor `rake pot` drives. GNU xgettext claims
            # to support Ruby but only shells out to this, so without it
            # `xgettext --language=Ruby` fails.
            pkgs.rubyPackages_3_4.gettext
            # The spec runner. The suite is plain RSpec, so this is enough.
            pkgs.rubyPackages_3_4.rspec
            # This machine may have no display server at all, so the shell
            # carries one it can start itself: `xvfb-run ruby exe/<app>` both
            # launches the app and is how test/drive_*.rb is run.
            pkgs.xvfb-run
            # Real X11 input synthesis for test/drive_middle_click.rb: a
            # Gtk::GestureClick#signal_emit fires the signal but leaves
            # gesture.current_button at 0, so the middle-click branch in
            # BrowseView#on_pressed / SearchView#on_pressed can only be
            # exercised by an actual pointer event through the display.
            pkgs.xdotool
            pkgs.gsettings-desktop-schemas
            pkgs.adwaita-icon-theme
            # `rake data:validate` shells out to these and silently skips
            # whichever one is missing; without them the task ran and
            # validated nothing. appstream-glib is `appstream-util`, the
            # older, stricter validator Flathub itself gates on
            # (upstream's data/meson.build:38) — a different binary from
            # `appstream`'s `appstreamcli`, not a duplicate.
            pkgs.desktop-file-utils
            pkgs.appstream
            pkgs.appstream-glib
          ] ++ gtkStack;

          # Icons, GSettings schemas and the GTK portal all resolve through
          # XDG_DATA_DIRS; without these the window opens with blank icons.
          shellHook = ''
            export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}:${pkgs.adwaita-icon-theme}/share:$XDG_DATA_DIRS"
            export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
            # bundlerEnv installs the platform gem ashpd, so forcing the ruby
            # platform asks bundler for a gem which is not there.
            export BUNDLE_FORCE_RUBY_PLATFORM=false
            export RUBYLIB="$PWD/lib''${RUBYLIB:+:$RUBYLIB}"
            # Compiled on every shell entry, not left for a developer to
            # remember `rake schema:compile` — otherwise the schema is only
            # reachable after that manual step and Settings silently falls
            # back to its per-process JSON file instead.
            mkdir -p data/schemas
            cp data/app.gschema.xml data/schemas/org.rubygtkproject.Biblioteca.gschema.xml
            ${pkgs.glib.dev}/bin/glib-compile-schemas data/schemas
            export GSETTINGS_SCHEMA_DIR="$PWD/data/schemas"
            unset BUNDLE_GEMFILE BUNDLE_FROZEN
            echo "Biblioteca devshell — ruby $(ruby -e 'print RUBY_VERSION')"
            echo "run the app:   xvfb-run ruby exe/biblioteca"
            # A screen argument, not just a display: xvfb-run's default screen
            # is 640x480, GTK clamps a window to the monitor, and at 640px wide
            # the window's "max-width: 850sp" breakpoint is applied the whole
            # time, so the wide layout can never be driven. The drive script
            # asserts the screen is big enough rather than quietly testing half
            # the layout.
            echo "drive the app: xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_biblioteca.rb"
            echo "run the specs: ruby -e 'require \"rspec/core\"; exit RSpec::Core::Runner.run([\"--format\", \"progress\", \"--require\", \"spec_helper\", \"spec\"])'"
          '';
        };
      });
}
