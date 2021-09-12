# PiSafe  -  Raspberry Pi imaging app

Backup or Restore Raspberry Pi devices (SD-cards, USB sticks, SSD drive) to/from compressed image-files right on your Pi!

 - Backup an SD card to an image-file.

 - Restore an image-file to an SD card.

 - Works entirely on a Raspberry Pi.  No Windows or Mac needed. 
 
 - Creates a compressed image-file that will resize to fill the new card it is restored to (thanks to PiShrink!).
 
 - Supports .img .zip .xz and .gz file formats.

 - Images are compatible with Raspberry PI Imager that comes with the Pi and probably all other imaging software.
 
 - Supports USB storage devices.
 
 - Supports backing up the live boot SD-card - but be careful, backing up a drive that is being written to can result in a courupted backup.  You have to turn off "hide root device" in "settings", "options" to enable this. 
 
    CAUTION: Reboot first, close everything and don't use the system while it is backing up!  You must send your backup image to a different drive

 - Supports storing the image files on a mounted network device (ie SMB server). 
   
    - mkdir shared
   
    - sudo mount.cifs //192.168.1.18/shared shared -o user=USERNAME,vers=1.0

 - Create a library of your own pi images, then restore them to whatever device you want, whenever you want.  
 
 - Can be run fully from the command line.

 - Should work with most debian and arch distros, see below.   

 - See Leepspvideo nice review on youtube:  https://www.youtube.com/watch?v=XP6ycUR9Ih0  -- "Very Impressive", "Makes a nice small image", "Really good all-in-one solution"
   
 .   

# INSTALL

In a terminal window, type in

    
    wget https://raw.githubusercontent.com/RichardMidnight/pi-safe/main/pisafe -O pisafe
    bash pisafe
    
    Then you can select 'tools' 'install' from the menu to install it into your Raspberry Pi menu
 
 
 
# SIMPLE SETUP
 
  1) You will need a large "Master" SD-card (eg 32GB), a smaller "Source" SD-card (eg 8GB) and a USB-SD-card reader.
  
  2) Install Raspberry PI OS on an SD card that is large enough to hold some SD image-files.  32GB or 64GB will do.  This is your "Master" SD-card.
   
   3) Boot from the "Master" card and install Pi-Safe on it.
   
   4) Install Raspberry PI OS or whatever OS you want on the "Source" SD-card.  Use as small of an SD-card as you can because the entire card is read in before it is shrunk and compressed.  I have been using Sandisk Industrial 8GB cards.

   5) Boot from the "Source" card (8GB), make changes, install other softwaare, change the desktop, whatever you want.

   6) To make an image of the "Source" (8GB) card that you can restore anytime in the future do the following...
  
  

  
# USAGE - MAKE AN IMAGE FILE  
   
   1) Boot your Pi with your Master SD-card as above.
   
   2) Put your Source SD-card (8GB) in the USB SD reader and insert it in a Pi USB port.
   
   3) Startup Pi-Safe from the menu.  Or in a terminal, type in 'pisafe'
        
   4) Use the menu to select BACKUP, select your SD-card and give the image-file a name.
   
   5) Watch your image-file get created, shrunk and compressed automatically.
    
 
   
   
# COMPATIBILITY   

Originally developed and tested on Raspberry pi 4 running Raspberry Pi OS Buster.

Also tested on RaspiOS-arm64, Raspberry Pi Desktop, Raspbian Stretch, Ubuntu 20.20 for Rpi, Linux Mint, LMDE.

v1.0.5 Added support for other terminals: lxterminal, gnome-terminal, xfce-terminal, mate-terminal, konsole, xterm, uxterm, qterminal.

V1.0.5 Added support for other text editors: leafpad, mousepad, gedit, kwrite, pluma, featherpad, xed, geany, kate, nano.

V1.1.0 Added support for Manjaro and maybe other Arch-based distros.
 
   
   
 # REFERENCES
 
Thanks to Raspberry Pi for how to read and write an image file.

Thanks to https://github.com/Drewsif/PiShrink for the PiShrink engine.

Thanks to all the people who posted code snipets on the web.

    
