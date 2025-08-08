# PiSafe – Raspberry Pi & Linux Imaging Utility

**Backup and restore Raspberry Pi systems — or many Linux systems — quickly and easily.**
PiSafe lets you create compressed image files of SD cards, USB drives, HDDs, SSDs or NVMes, and restore them whenever you need. Great for creating restore points. 

- 🍓 Designed for Raspberry Pi — works with most Linux distros  
- 🐧 Runs entirely on Linux — no Windows or macOS required  
- 💾 Compatible with Raspberry Pi Imager and other tools  
- 🎛 Simple menu interface or command-line automation  
- 📦 Creates compressed images that auto-expand on restore

---

## Features
- **Backup → image** and **Restore → media** with menu or CLI options  
- Shrinks ext* filesystems (ext4, ext3, ext2) on backup and auto-expands on first boot (when supported)  
- Multiple compression options: zip, xz, gz, zst (installs tools as needed)  
- Supports `.img`, `.zip`, `.xz`, `.gz`, `.zst` formats  
- Works with USB drives, network storage (SMB/NFS), and live boot media (with caution)  
- Compatible with Raspberry Pi Imager and similar imaging tools  
- Build a library of system images for fast restores  
- Ideal for creating restore points during development projects  
- [Leepspvideo review](https://www.youtube.com/watch?v=XP6ycUR9Ih0): “Very Impressive,” “Makes a nice small image,” “Really good all-in-one solution”
---

## Install
Paste or type this into a terminal window:

```bash
wget https://raw.githubusercontent.com/RichardMidnight/pi-safe/main/pisafe -O pisafe
bash pisafe install
```

**Beta Version**
```bash
wget https://raw.githubusercontent.com/RichardMidnight/pi-safe/main/pisafe_beta -O pisafe
bash pisafe install
```

**Old Stable** (in case current version has issues)
```bash
wget https://raw.githubusercontent.com/RichardMidnight/pi-safe/main/pisafe_1.2.9 -O pisafe
bash pisafe install
```

---

## Quick Start

**1) Prepare your "Master" SD card**  
Install your preferred OS and PiSafe on an SD card that is large enough to hold images (32GB or 64GB recommended).

**2) Prepare your “Project” card**  
Install your OS (e.g., Raspberry Pi OS, Debian, Ubuntu, Manjaro) on a smaller SD card (e.g., 8GB SanDisk Industrial). Customize it.

**3) Create an image**
1. Boot your Pi with your "Master" SD card.  
2. Put your "Project" SD card in a USB SD reader and insert it into a Pi USB port.  
3. Start PiSafe from the menu or in a terminal by typing: pisafe
4. Select **Backup**, choose the Project card, name the image, and let PiSafe create, shrink, and compress it automatically.

---

## Release notes

Originally developed and tested on Raspberry Pi 4 running Raspberry Pi OS Buster.  
Also tested on RaspiOS-arm64, Raspberry Pi Desktop, Raspbian Stretch, Ubuntu 20.04 for Raspberry Pi, Linux Mint, LMDE.

- **v1.2.10** — Adds support for Bookworm and NVMe media  
- **v1.2.9** — Started adding command-line settings override options (undocumented)  
- **v1.2.7** — Fixed issue with pigz and xz  
- **v1.2.5m** — Fixed non-English language issue, added zstd compression, gz/xz/zst only install as needed  
- **v1.2.5** — Improved support for Manjaro, Arch, SUSE, and Fedora  
- **v1.2.4** — Backup with `-y` bypasses update check  
- **v1.2.3** — Fixed bug with available space on network shares  
- **v1.2.0** — Added `ignore_freespace_at_end`, added erase (FAT32, exFAT, NTFS, ext4)  
- **v1.1.0** — Added support for Manjaro and other Arch-based distros  
- **v1.0.5** — Added support for more terminals and text editors

---

## Tips

PiSafe is optimized for Raspberry Pi OS around 2020. It will work with many other Linux distributions and hardware, but some features may not be optimized. These tips can help you get the best results.

### Ignore freespace at end of media
- PiSafe will ignore freespace at the end of the media, speeding up backups and using less working space.  
- To take advantage of this, resize partitions with `gparted` and leave unallocated space at the end of the media.  
- Freespace not at the end of the media cannot be ignored.

### Shrinking the filesystem on backup
- Creates a smaller image file and allows restores to different-size media.
- Requires the main ext4/ext3/ext2 partition to be the last on the media.
- Standard Debian installs often place swap last; remove/move swap to allow shrinking.
- Optionally, zero out deleted files with `bleachbit` before shrinking for better compression.

### Auto-expand filesystem on restore
- If your distro supports `rc.local`, PiSafe will auto-expand on first boot.  
- If not, you can resize manually using `gparted` from another boot device.
- Auto-expand may not work on overlay filesystems — turn it off in Settings/Options if needed.

### Data compression
Compressing the image file with zip, xz, gz, or zst reduces the size of the image file to around 1/2.

Standard compression levels are 1 through 9. A higher number will compress the file a little more but take a lot more time.
- **Fastest:** `zst 1`  
- **Smallest:** `xz 8` (or higher, limited by memory)  
- **Default:** `zip 1` (industry-standard balance)
---

### Overlay FS (Raspberry Pi Desktop x86 & Overlay Mode)

PiSafe’s shrink/expand features are designed for a normal writable ext* root filesystem.  
Systems that use an **overlay** root (e.g., Raspberry Pi Desktop for PC/Mac running as a live/persistent image, or Raspberry Pi OS with “Overlay FS” enabled in `raspi-config`) don’t work well with shrink/auto-expand and may produce incomplete or read-only restores.

**Workarounds:**
- Disable Overlay FS in `sudo raspi-config` and reboot before running PiSafe  
- Or boot another Linux system and back up the target disk “cold” (not the live root)  
- If you must stay on overlay, run PiSafe without shrink/auto-expand (raw image)  
- Consider a file-level rsync backup as an alternative

**Check if overlay is active:**
```bash
mount | grep -w overlay
```
---

## Example: mounting an SMB network share

```bash
sudo apt install cifs-utils
mkdir shared
sudo mount.cifs //192.168.1.18/shared shared -o user=USERNAME,vers=3.0
```

**Legacy SMB1 example** (only if required — insecure):
```bash
sudo mount.cifs //omv.local/shared shared -o guest,vers=1.0
```


## References
Thanks to the Raspberry Pi Foundation for instructions on reading/writing image files.  
Thanks to [PiShrink](https://github.com/Drewsif/PiShrink) for the shrink engine.  
Thanks to the open-source community for inspiration and code snippets.
