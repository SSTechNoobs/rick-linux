#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ISO_DIR="$ROOT/iso"

VERSION="${1:?Usage: sudo bash iso/build-iso.sh v1.0.3}"

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Version must look like v1.0.3"
    exit 1
fi

BUILD_USER="${SUDO_USER:-$USER}"
BUILD_HOME="$(getent passwd "$BUILD_USER" | cut -d: -f6)"

[[ -n "$BUILD_HOME" && -d "$BUILD_HOME" ]] || {
    echo "ERROR: Cannot locate build user's home directory."
    exit 1
}

if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
    echo "ERROR: Repository has uncommitted or untracked changes."
    echo "Commit or remove them before building the ISO."
    exit 1
fi

LOCAL_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
REMOTE_HEAD="$(git -C "$ROOT" rev-parse origin/main 2>/dev/null || true)"

if [[ -z "$REMOTE_HEAD" || "$LOCAL_HEAD" != "$REMOTE_HEAD" ]]; then
    echo "ERROR: Local HEAD is not synchronized with origin/main."
    echo "Push or synchronize the repository before building the ISO."
    exit 1
fi

PIN="$LOCAL_HEAD"

PROFILE="$BUILD_HOME/.cache/rick-linux-iso-profile"
WORK="$BUILD_HOME/.cache/rick-linux-archiso-work"
OUT="$BUILD_HOME/Projects/Ricks-Hyprland-ISOs/$VERSION"

if ! command -v mkarchiso >/dev/null 2>&1; then
    echo "ERROR: mkarchiso is missing."
    echo "Install the archiso package first."
    exit 1
fi

if [[ ! -d /usr/share/archiso/configs/releng ]]; then
    echo "ERROR: ArchISO releng profile was not found."
    exit 1
fi

if [[ -e "$OUT" ]]; then
    echo "ERROR: ISO output folder already exists: $OUT"
    echo "Refusing to overwrite an existing ISO."
    exit 1
fi

# Protect against deleting unexpected build paths.
for dir in "$PROFILE" "$WORK"; do
    case "$dir" in
        "$BUILD_HOME/.cache/rick-linux-iso-profile"|\
"$BUILD_HOME/.cache/rick-linux-archiso-work")
            ;;
        *)
            echo "ERROR: Unsafe build directory: $dir"
            exit 1
            ;;
    esac

    if [[ -L "$dir" ]]; then
        echo "ERROR: Build directory is a symbolic link: $dir"
        exit 1
    fi
done

sudo rm -rf -- "$PROFILE" "$WORK"
mkdir -p "$OUT"

cp -a /usr/share/archiso/configs/releng "$PROFILE"

mkdir -p "$PROFILE/airootfs/usr/local/bin"

sed "s/@PIN@/$PIN/" \
    "$ISO_DIR/rick-install.in" \
    > "$PROFILE/airootfs/usr/local/bin/rick-install"

chmod 755 "$PROFILE/airootfs/usr/local/bin/rick-install"

while IFS= read -r package; do
    [[ -z "$package" ]] && continue

    grep -qxF "$package" "$PROFILE/packages.x86_64" || \
        echo "$package" >> "$PROFILE/packages.x86_64"
done < "$ISO_DIR/packages.x86_64"

sed -i \
    's/^iso_name=.*/iso_name="rick-linux"/' \
    "$PROFILE/profiledef.sh"

sed -i \
    's/^iso_label=.*/iso_label="RICK_$(date +%Y%m)"/' \
    "$PROFILE/profiledef.sh"

sed -i \
    's/^iso_publisher=.*/iso_publisher="Ricks Linux <https:\/\/github.com\/SSTechNoobs\/rick-linux>"/' \
    "$PROFILE/profiledef.sh"

sed -i \
    's/^iso_application=.*/iso_application="Ricks Linux Live\/Installer"/' \
    "$PROFILE/profiledef.sh"

cat >> "$PROFILE/profiledef.sh" <<'PROFILE_EOF'

# Ricks Linux installer launcher
file_permissions["/usr/local/bin/rick-install"]="0:0:755"
PROFILE_EOF

echo
echo "Building Ricks Linux ISO pinned to:"
echo "$PIN"
echo

sudo mkarchiso -v \
    -w "$WORK" \
    -o "$OUT" \
    "$PROFILE"

echo
echo "=== VERIFY AND FINALIZE ISO ==="

shopt -s nullglob
isos=("$OUT"/rick-linux-*.iso)

if (( ${#isos[@]} == 0 )); then
    echo "ERROR: No ISO file was created."
    exit 1
fi

chown "$BUILD_USER:$(id -gn "$BUILD_USER")" "$OUT" "${isos[@]}"
sha256sum "${isos[@]}"

echo
echo "=== BUILD COMPLETE ==="
