# proxmox

Small Proxmox/Linux helper scripts.

## Scripts

- `setIPAddress.sh` updates a VM's Netplan config, resets machine-id (useful for cloned VMs), and runs `netplan apply`.

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
