# PiSafe  -  Raspberry Pi imaging app

Backup or Restore Raspberry Pi media (SD-cards, USB sticks, SSD drive, ...) to/from compressed image-files right on your Pi!

 - Backup an SD card (or other media) to an image-file.

 - Restore an image-file to an SD card (or other media).

 - Works entirely on a Raspberry Pi (or other linux).  No Windows or Mac needed. 
 
 - Creates a compressed image-file that will resize to fill the new media to which it is restored.
 
 - Supports .img .zip .xz .gz and .zst file formats.

 - Images are compatible with popular imaging software such as Raspberry PI Imager.
 
 - Supports USB storage devices.
 
 - Supports backing up the live boot media - but be careful, backing up media that is being written to can result in a corrupted backup.  You have to turn off "hide root device" in "settings", "options" to enable this. 
 
    CAUTION: Reboot first, close everything and don't use the system while it is doing step 1 of backing up!  You must send your backup image to a different drive.

 - Supports storing the image files on a mounted network device (ie an SMB server). 
   
   -  sudo apt install cifs-utils 
   
    - mkdir shared
   
    - sudo mount.cifs //192.168.1.18/shared shared -o user=USERNAME,vers=1.0

 - Create a library of your own pi images, then restore them to whatever media you want, whenever you want.  
 
 - Can be run from the command line or use the easy menu interface.

 - Should work with most debian and arch distros, see below.   

 - See Leepspvideo nice review on youtube:  https://www.youtube.com/watch?v=XP6ycUR9Ih0  -- "Very Impressive", "Makes a nice small image", "Really good all-in-one solution"
   

# Install

Paste or type this into a terminal window:

    
    wget https://raw.githubusercontent.com/RichardMidnight/pi-safe/main/pisafe -O pisafe
    bash pisafe install
 
 
Beta version:

    wget https://raw.githubusercontent.com/RichardMidnight/pi-safe/main/pisafe_beta -O pisafe
    bash pisafe install
    
 
 
# Simple Setup
  
   1) Install Raspberry PI OS and PiSafe on an SD card that is large enough to hold some SD image-files.  32GB or 64GB will do.  This is your "Master" SD-card.  Set this aside.
   
   2) Install Raspberry PI OS or whatever OS you want on the "Source" SD-card.  Use as small of an SD-card as you can because the entire card is read before it is shrunk and compressed.  I have been using Sandisk Industrial 8GB cards.  Make changes, install other software, change the desktop, whatever you want.

   3) To make an image of the "Source" (8GB) card that you can restore anytime in the future do the following...
  
  
  
# Usage - make an image file 
   
   1) Boot your Pi with your "Master" SD-card as above.
   
   2) Put your "Source" SD-card (8GB) in the USB SD reader and insert it in a Pi USB port.
   
   3) Startup pisafe from the menu.  Or in a terminal, type in 'pisafe'
        
   4) Use the menu to select BACKUP, select your SD-card and give the image-file a name.
   
   5) Watch your image-file get created, shrunk and compressed automatically.
    
 
   
   
# Release notes   

Originally developed and tested on Raspberry pi 4 running Raspberry Pi OS Buster.

Also tested on RaspiOS-arm64, Raspberry Pi Desktop, Raspbian Stretch, Ubuntu 20.20 for Rpi, Linux Mint, LMDE.

v1.0.5 Added support for other terminals: lxterminal, gnome-terminal, xfce-terminal, mate-terminal, konsole, xterm, uxterm, qterminal.

V1.0.5 Added support for other text editors: leafpad, mousepad, gedit, kwrite, pluma, featherpad, xed, geany, kate, nano.

V1.1.0 Added support for Manjaro and probably other Arch-based distros.

v1.2.0 Cleaned up the code a lot, added "ignore_freespace_at_end", added erase (fat32, exfat, ntfs, ext4).  

v1.2.3 Cleaned up more code. Fixed bug in available-space on network-shares which halted backup.

v1.2.4 Cleaned up more code.  Backup with -y bypasses check_for_updates.

v1.2.5 Improved support for Manjaro, Arch, Suse and Fedora.

v1.2.5 m (beta) Fixed issue with non-english languages.  Added support for zstd compression.  Made gz, xz and zst only install as needed.

v.1.2.7 (beta) Fixed issue with pigz and xz.
 
   
 # Tips
 PiSafe is optimized for Raspberry Pis running Raspios around the year 2020.  It will work with many other linux distributions and other hardware but some features may not be optimized or may not work at all depending on the configuration.  The following tips can help you optimize PiSafe for your configuration.
 
  - Ignore Freespace at end of media
    - PiSafe will ignore freespace at the end of the media, speeding up the backup process and using less working space.  
    - If you have a small amount of data on a large media (eg using 10GB of a 500GB drive), you can resize your partitions (with gparted) and leave freespace (unallocated) at the end of the media which PiSafe will ignore.  Note, freespace not at the end of the media cannot be ignored.
 
  - Shrinking the filesystem on backup  
    - Shrinking the filesystem is VERY VALUABLE because it creates a smaller image file, and allows you to restore the image to a different size media.
    - PiSafe will shrink your filesystem if your main partition is ext4 (and maybe ext3 and ext2) and is the last partition on the media.
    - If your install does not default to this partitioning setup you should be able to custom partition the media during your OS installation and put the main ext4 partition at the end.  This is needed with standard debian installations including RPD and Linux Mint because they put a swap partition at then end of the media which blocks PiSafe from shrinking the filesystem.
    - Alternatively if your main partition is the second to last one and the last one is a swap partition, you may be able to simply delete the swap partition.
    - Alternatively you can zero-out your deleted files with bleachbit to optimize compression and then shrink your partitions with gparted.
    
 - Auto-expand filesystem on restore   
    - PiSafe will setup the image file to auto-expand to fill the new media on first boot after restoring if your distro supports rc.local.  
    - If not, you can resize your partition manual by booting from another media and using gparted.
    - Note: Auto-expand may not work on an overlay filesystem.  Recommend turning off auto-expand in Settings/Options.  
   
 - Data compression
    - Compressing the image file with zip, xz, gz, or zst reduces the size of the image file to around 1/2.  
    - zst is the fastest.
    - xz makes the smallest file. 
    - The default is the industry standard zip.
    - The default data compression level is set to 1 out of 9.  A higher setting will compress the file a bit more but can take a lot more time.
   
 # References
 
Thanks to the Raspberry Pi foundation for instructions on how to read and write an image file.

Thanks to https://github.com/Drewsif/PiShrink for the PiShrink engine.

Thanks to all the people who posted code snipets on the web.

    
