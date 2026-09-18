# nixpkg-browser-cli

Nix flake package for [`browser-cli`](https://github.com/Mic92/mics-skills/tree/main/browser-cli) bundled with:
1. Firefox WebExtension (`browser-cli-controller@thalheim.io.xpi`).
2. Enterprise `policies.json` for seamless auto-install in Firefox without security prompts.
3. Automated setup script (`browser-cli-setup`) for persistent headless Browsh and GUI Firefox integration.

## Installation

### Via Flox
In `~/.flox/env/manifest.toml`:
```toml
browser-cli.flake = "github:RogerNavelsaker/nixpkg-browser-cli"
```

### Via Nix Flake
```bash
nix profile install github:RogerNavelsaker/nixpkg-browser-cli
```

Or run directly:
```bash
nix run github:RogerNavelsaker/nixpkg-browser-cli -- --help
```

## Setup & Autoloading

Run the included setup helper:
```bash
browser-cli-setup
```

### Autoloading in GUI Firefox
To allow your normal Firefox (with existing profiles and logins) to automatically load the extension:

```bash
sudo mkdir -p /etc/firefox/policies
sudo ln -sf $(nix eval --raw github:RogerNavelsaker/nixpkg-browser-cli#policies.outPath)/policies.json /etc/firefox/policies/policies.json
```

Or if using user-level policies:
```bash
mkdir -p ~/.config/mozilla/firefox/policies
ln -sf $(nix eval --raw github:RogerNavelsaker/nixpkg-browser-cli#policies.outPath)/policies.json ~/.config/mozilla/firefox/policies/policies.json
```

### Autoloading in Browsh
`browser-cli-setup` automatically copies the extension and native messaging host into `~/.config/browsh/firefox_profile/extensions/`.
When Firefox GUI is not running, `browser-cli` will auto-spawn Browsh in headless mode with the extension active.
