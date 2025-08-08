# PiSafe – Raspberry Pi & Linux Imaging Utility

**Backup and restore Raspberry Pi systems — or almost any Linux install — quickly and easily.**
PiSafe lets you create compressed image files from SD cards, USB drives, or SSDs, and restore them whenever you need. Great for creating restore points. 

- 🐧 Designed for Raspberry Pi, **works with most Debian, Ubuntu, Arch, and other Linux distros**
- 💻 Runs entirely on Linux — no Windows or macOS required
- 🔄 Produces images compatible with Raspberry Pi Imager and similar tools
- 🎛 Simple menu interface or command-line mode for automation

---

## Features
- **Backup → image** and **Restore → media** with a simple menu or CLI.
- **Shrinks ext* filesystems** (ext4, ext3, ext2) on backup and **auto-expands on first boot** (when supported) so images restore to different-sized media. 
- **Compression:** zip, xz, gz, zst (installs tools on demand).
- **Formats supported:** `.img`, `.zip`, `.xz`, `.gz`, `.zst`.
- **USB & network storage:** save to external drives or mounted shares (SMB/NFS).
- Works with most **Debian** and **Arch Linux** distros (see below).
- Images are compatible with tools like **Raspberry Pi Imager**.
- Create a library of your own Pi images, then restore them to whatever media you want, whenever you want.
- Ideal for creating restore points during Raspberry Pi or Linux development projects.
- [Leepspvideo review on YouTube](https://www.youtube.com/watch?v=XP6ycUR9Ih0) — “Very Impressive,” “Makes a nice small image,” “Really good all-in-one solution”.
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
Install Raspberry Pi OS and PiSafe on an SD card that is large enough to hold images (32GB or 64GB recommended). This is your "Master" card.

**2) Prepare your “Project” card**  
Install Raspberry Pi OS (or another OS) on a smaller SD card (e.g., 8GB SanDisk Industrial). Customize it.

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

---

## References
Thanks to the Raspberry Pi Foundation for instructions on reading/writing image files.  
Thanks to [PiShrink](https://github.com/Drewsif/PiShrink) for the shrink engine.  
Thanks to all who posted code snippets on the web.

    
