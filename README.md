# Omarchy Dell Controls

An [Omarchy](https://omarchy.org) shell bar widget that does on Linux what Dell Power Manager / My Dell do on Windows. Built for and tested on an XPS 15 9510; it should work on any Dell laptop that loads the kernel's `dell_laptop`, `dell_pc` and `dell_smm_hwmon` drivers.

- **Battery:** charge level, health (full vs. design capacity), temperature, power draw, manufacture date, service tag, BIOS version
- **Charging modes:** Standard, Adaptive, Custom (with start/stop thresholds), Fast, Trickle. These are stored in the BIOS, so they also apply in Windows
- **Thermal profile:** Cool, Quiet, Optimized, Ultra Performance (the BIOS thermal tables)
- **Fans:** live RPM, and Auto / Medium / Max. Manual modes run a watchdog that hands control back to the BIOS if the CPU reaches 85°C
- **CPU:** temperature, clock, energy-performance preference, Turbo on/off
- **NVIDIA GPU:** asleep or awake, power, temperature, P-state, and which processes are keeping it awake. It never wakes a sleeping GPU just to read it

## Install

```bash
omarchy plugin add https://github.com/cbrompton/omarchy-dell-controls.git --enable
```

The panel can display information right away. To let it change settings, install the root helper and polkit rule once:

```bash
sudo ~/.config/omarchy/plugins/cbrompton.dell/install.sh
```

This puts `dell-ctl-helper` in `/usr/local/libexec` (root-owned) and adds a polkit action that lets the active local user run it without a password. The helper only accepts a fixed set of commands and validates every value against what the kernel advertises. Remove both with `sudo ./install.sh --uninstall`. Re-run the installer after updating the plugin so the installed helper matches.

## Usage

- **Left-click** the fan icon to open the panel
- **Right-click** to show the CPU temperature next to the icon
- `omarchy-shell cbrompton.dell toggle` to open it from a keybinding

### Service tag

Linux only lets root read the service tag. If the panel shows "—", add it to the widget's entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "cbrompton.dell", "serviceTag": "ABC1234" }
```

## Notes

- The Omarchy power menu and this panel's thermal profile change the same BIOS setting; whichever you pick last wins.
- Some BIOSes ignore manual fan speeds. If Medium/Max doesn't change the RPM, use the thermal profile instead.
- Dell doesn't report battery cycle count on many models.
