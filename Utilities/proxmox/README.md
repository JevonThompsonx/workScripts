← [Back to Utilities](../README.md)

# proxmox

Small Proxmox/Linux helper scripts.

## Scripts

| File | Description | Elevation | Key Parameters |
|------|-------------|-----------|----------------|
| [setIPAddress.sh](setIPAddress.sh) | Updates a VM's Netplan config, resets machine-id (for cloned VMs), and runs `netplan apply` | Required (root) | (edit variables at top of script) |

## Usage

1. Copy the script to the target VM.
2. Run as root:

```bash
sudo bash ./setIPAddress.sh
```

## Notes

- Defaults are hardcoded inside the script:
  - Netplan file: `/etc/netplan/50-cloud-init.yaml`
  - Interface: `ens18`
  - Gateway/DNS: `192.168.0.1`
- If your interface/subnet differs, edit the variables at the top of the script.
