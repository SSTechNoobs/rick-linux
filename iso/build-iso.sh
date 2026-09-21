#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ISO_DIR="$ROOT/iso"

PIN="10595a537197e0aae3540e26521e1460f0665836"

PROFILE="$HOME/.cache/rick-linux-iso-profile"
WORK="$HOME/.cache/rick-linux-archiso-work"
OUT="$HOME/Downloads/ricks-linux-v1.0.1"

if ! command -v mkarchiso >/dev/null 2>&1; then
    echo "ERROR: mkarchiso is missing."
    echo "Install the archiso package first."
    exit 1
fi

if [[ ! -d /usr/share/archiso/configs/releng ]]; then
    echo "ERROR: ArchISO releng profile was not found."
    exit 1
fi

sudo rm -rf "$PROFILE" "$WORK" "$OUT"
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
echo "=== BUILD COMPLETE ==="
sha256sum "$OUT"/rick-linux-*.iso
