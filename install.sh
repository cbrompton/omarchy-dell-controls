#!/bin/bash
# Install the root helper and polkit policy the Dell panel needs to change
# settings. Run once with: sudo ./install.sh   (re-run after editing the helper)
# Remove with:            sudo ./install.sh --uninstall
set -euo pipefail

HELPER=/usr/local/libexec/dell-ctl-helper
POLICY=/usr/share/polkit-1/actions/local.dell-ctl.policy
HERE=$(cd "$(dirname "$0")" && pwd)

[[ $EUID -eq 0 ]] || { echo "Run with sudo" >&2; exit 1; }

if [[ ${1:-} == --uninstall ]]; then
  "$HELPER" fan auto 2>/dev/null || true
  rm -f "$HELPER" "$POLICY"
  echo "Removed $HELPER and $POLICY"
  exit 0
fi

install -D -o root -g root -m 0755 "$HERE/bin/dell-ctl-helper" "$HELPER"

# allow_active=yes: the logged-in local user can run this one helper without a
# password prompt. The helper only accepts whitelisted commands and values.
cat > "$POLICY" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
  "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <action id="local.dell-ctl">
    <description>Change Dell battery, thermal, fan and CPU settings</description>
    <message>Authentication is required to change Dell hardware settings</message>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>auth_admin</allow_inactive>
      <allow_active>yes</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">$HELPER</annotate>
  </action>
</policyconfig>
EOF
chmod 0644 "$POLICY"
echo "Installed $HELPER and $POLICY"
