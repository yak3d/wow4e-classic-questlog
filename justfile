# Classic Quest Log -- development recipes
#
# Symlinks the addon folder into a World of Warcraft install so edits are picked
# up with /reload. Run `just` for recipes and the resolved paths.

# On Windows, recipes run under Git Bash (mklink and cygpath are used below).
set windows-shell := ["sh", "-cu"]

ADDON_NAME := "ClassicQuestLog"

# Client folders (under WOW_DIR) to install into. `just install _retail_`
# limits a run to one of them.
FLAVORS := "_forever_ _classic_beta_"
SRC_DIR := justfile_directory() / ADDON_NAME
CONFIG_FILE := justfile_directory() / ".wow_path"

# ---------------------------------------------------------------------------
# WoW install location
# ---------------------------------------------------------------------------
# Resolution order: `just WOW_DIR=... <recipe>`, then the WOW_DIR environment
# variable, then the cached value in .wow_path, then the per-OS default below.
DEFAULT_WOW_DIR := if os() == "windows" {
    "C:/Program Files (x86)/World of Warcraft"
} else if os() == "macos" {
    "/Applications/World of Warcraft"
} else {
    home_directory() / "Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft"
}
WOW_DIR := env("WOW_DIR", if path_exists(CONFIG_FILE) == "true" { trim(read(CONFIG_FILE)) } else { DEFAULT_WOW_DIR })

# Show recipes and the resolved paths
help:
    @{{ quote(just_executable()) }} --justfile {{ quote(justfile()) }} --list --unsorted
    @echo ""
    @echo "Variables (set before the recipe, e.g. just WOW_DIR=\"/path/to/World of Warcraft\" install):"
    @echo "  WOW_DIR    {{ WOW_DIR }}"
    @echo "  FLAVORS    {{ FLAVORS }}"
    @{{ if path_exists(CONFIG_FILE) == "true" { "echo; echo \"WOW_DIR is cached in .wow_path; run 'just reset' to forget it.\"" } else { "true" } }}

# ---------------------------------------------------------------------------
# Recipes
# ---------------------------------------------------------------------------

# Verify WOW_DIR exists
check-wow-dir:
    @test -d {{ quote(WOW_DIR) }} || { echo "WOW_DIR does not exist: {{ WOW_DIR }}"; echo "Pass it as: just WOW_DIR=\"/path/to/World of Warcraft\" install"; exit 1; }

# Symlink the addon into every installed flavor (or only FLAVOR) and cache WOW_DIR in .wow_path
install flavor="": check-wow-dir (_each-flavor "link" flavor)
    @printf '%s\n' {{ quote(WOW_DIR) }} > {{ quote(CONFIG_FILE) }}

# Remove the addon symlink from every installed flavor (or only FLAVOR)
uninstall flavor="": check-wow-dir (_each-flavor "unlink" flavor)

# Forget the cached WOW_DIR
reset:
    @rm -f {{ quote(CONFIG_FILE) }}
    @echo "Cleared .wow_path"

# Run luacheck on the addon (skipped if luacheck is not installed)
lint:
    @if command -v luacheck >/dev/null 2>&1; then luacheck {{ quote(ADDON_NAME) }}; else echo "luacheck not found; install with: luarocks install luacheck"; fi

# Runs `action` (link or unlink) for each flavor folder that exists under
# WOW_DIR, skipping the rest, and fails if none exist. An empty `flavor` means
# every entry in FLAVORS.
[private]
_each-flavor action flavor:
    #!/usr/bin/env sh
    set -eu
    wow_dir={{ quote(WOW_DIR) }}
    src={{ quote(SRC_DIR) }}
    flavors={{ if flavor == "" { quote(FLAVORS) } else { quote(flavor) } }}

    if [ "${OS:-}" = Windows_NT ]; then
        link_dest() { cmd //c mklink /J "$(cygpath -w "$1")" "$(cygpath -w "$src")" >/dev/null; }
        unlink_dest() { cmd //c rmdir "$(cygpath -w "$1")"; }
    else
        link_dest() { ln -sfn "$src" "$1"; }
        unlink_dest() { rm -rf "$1"; }
    fi

    found=0
    for flavor in $flavors; do
        if [ ! -d "$wow_dir/$flavor" ]; then echo "Skipping $flavor (not found in $wow_dir)"; continue; fi
        found=1
        dest="$wow_dir/$flavor/Interface/AddOns/{{ ADDON_NAME }}"
        case {{ quote(action) }} in
            link)
                mkdir -p "$(dirname "$dest")"
                if [ -e "$dest" ] || [ -L "$dest" ]; then unlink_dest "$dest"; fi
                link_dest "$dest" && echo "Installed {{ ADDON_NAME }} -> $dest"
                ;;
            unlink)
                if [ -e "$dest" ] || [ -L "$dest" ]; then unlink_dest "$dest"; echo "Removed $dest"; else echo "Nothing installed at $dest"; fi
                ;;
        esac
    done
    [ "$found" = 1 ] || { echo "None of the flavor folders exist under $wow_dir: $flavors"; exit 1; }
