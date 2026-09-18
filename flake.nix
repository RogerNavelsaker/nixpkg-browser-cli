{
  description = "browser-cli repackaged with Firefox extension & enterprise policies for automatic loading in Firefox and Browsh";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    mics-skills.url = "github:Mic92/mics-skills";
  };

  outputs = { self, nixpkgs, flake-utils, mics-skills }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        upstreamCli = mics-skills.packages.${system}.browser-cli;
        upstreamExt = mics-skills.packages.${system}.browser-cli-extension;

        extId = "browser-cli-controller@thalheim.io";

        # Generate policies.json pointing to the bundled XPI in the nix store
        policiesJson = pkgs.writeText "policies.json" (builtins.toJSON {
          policies = {
            ExtensionSettings = {
              "${extId}" = {
                installation_mode = "force_installed";
                install_url = "file://${upstreamExt}/browser-cli-extension.xpi";
              };
            };
          };
        });

        browserCliPackage = pkgs.symlinkJoin {
          name = "browser-cli-with-extension-${upstreamCli.version or "0.4.0"}";
          paths = [ upstreamCli ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            # 1. Provide the extension XPI in share/
            mkdir -p $out/share/browser-cli/extensions
            cp ${upstreamExt}/browser-cli-extension.xpi $out/share/browser-cli/extensions/${extId}.xpi

            # 2. Provide the policies.json for user/system symlinking
            mkdir -p $out/share/browser-cli/policies
            cp ${policiesJson} $out/share/browser-cli/policies/policies.json

            # 3. Provide setup helper script to automatically symlink policies and browsh profile
            mkdir -p $out/bin
            cat << 'EOF' > $out/bin/browser-cli-setup
            #!/usr/bin/env bash
            set -euo pipefail

            echo "==> Setting up browser-cli for Firefox & Browsh..."

            # 1. Native Messaging Host for Firefox / LibreWolf
            browser-cli --install-host

            # 2. Auto-load extension into Browsh headless profile
            BROWSH_EXT_DIR="$HOME/.config/browsh/firefox_profile/extensions"
            mkdir -p "$BROWSH_EXT_DIR"
            cp -f "@out@/share/browser-cli/extensions/@extId@.xpi" "$BROWSH_EXT_DIR/@extId@.xpi"
            echo "✓ Extension installed to Browsh profile ($BROWSH_EXT_DIR)"

            # Also ensure Native Messaging host is in Browsh profile
            mkdir -p "$HOME/.config/browsh/firefox_profile/native-messaging-hosts"
            if [ -f "$HOME/.mozilla/native-messaging-hosts/io.thalheim.browser_cli.bridge.json" ]; then
              cp -f "$HOME/.mozilla/native-messaging-hosts/io.thalheim.browser_cli.bridge.json" \
                "$HOME/.config/browsh/firefox_profile/native-messaging-hosts/"
            fi

            # 3. Symlink policies.json for GUI Firefox
            # Modern Firefox searches /etc/firefox/policies/ or distribution/policies.json
            POLICIES_SRC="@out@/share/browser-cli/policies/policies.json"
            echo "✓ policies.json generated at: $POLICIES_SRC"

            # Check if user has write access to /etc/firefox/policies
            if [ -w /etc/firefox/policies 2>/dev/null ] || [ -w /etc/firefox 2>/dev/null ]; then
              mkdir -p /etc/firefox/policies
              ln -sf "$POLICIES_SRC" /etc/firefox/policies/policies.json
              echo "✓ Symlinked to /etc/firefox/policies/policies.json"
            else
              echo "Note: To enable automatic loading in GUI Firefox without prompts, run:"
              echo "  sudo mkdir -p /etc/firefox/policies && sudo ln -sf $POLICIES_SRC /etc/firefox/policies/policies.json"
            fi

            echo "==> Setup complete!"
            EOF

            sed -i "s|@out@|$out|g" $out/bin/browser-cli-setup
            sed -i "s|@extId@|${extId}|g" $out/bin/browser-cli-setup
            chmod +x $out/bin/browser-cli-setup
          '';

          meta = upstreamCli.meta // {
            description = "Control Firefox browser from CLI (bundled with WebExtension and policies)";
          };
        };
      in
      {
        packages.default = browserCliPackage;
        packages.browser-cli = browserCliPackage;
        packages.extension = upstreamExt;
        packages.policies = pkgs.runCommand "browser-cli-policies" {} ''
          mkdir -p $out
          cp ${policiesJson} $out/policies.json
        '';
      }
    );
}
