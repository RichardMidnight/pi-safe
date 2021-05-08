# PiSafe  -  Raspberry Pi imaging app

Backup or Restore Raspberry Pi devices (SD-cards, USB sticks, SSD...) to/from a compressed image-file right on your Pi!

 - Backup an SD card to an image-file.

 - Restore an image-file to an SD card.

 - Works entirely on a Raspberry Pi.  No Windows or Mac needed. 
 
 - Creates a compressed image-file that will resize to fill the new card it is restored to (thanks to PiShrink!).
 
 - Supports .img .zip .xz and .gz file formats.

 - Images are compatible with Raspberry PI Imager that comes with the Pi and probably all other imaging software.
 
 - Supports all USB storage (I think).
 
 - Supports USB boot 
 
 - Seems to support backing up the live boot SD-card.  You have to turn off "hide root backup".  
    CAUTION: Reboot first, close everything and don't use the system while it is backing up!  You must send your backup image to a different drive!

 - Create a library of your own pi images, then restore them to whatever device you want, whenever you want.  
 
 - This adds a menu front-end to my 'sd' project which is a command-line version.

 - Should work with most debian and arch distros, see below.   

 - See Leepspvideo nice review on youtube:  https://www.youtube.com/watch?v=XP6ycUR9Ih0  -- "Very Impressive", "Makes a nice small image", "Really good all-in-one solution"
   
 
 .
 
# EXAMPLE
 
   1) Install Raspberry PI OS on an SD card that is large enough to hold some SD image-files.  32GB or 64GB will do.  This is your Master SD-card.
   
   2) Install Pi-Safe as described below.
   
   3) You will need a USB-SD reader for your source SD-card (8GB).
   
   4) You will need some SD cards.  Use as small of an SD-card as you can because the entire card has to be read in before it is shrunk and compressed.  I have been using Sandisk Industrial 8GB cards.

   5) Install Raspberry PI OS on a second (8GB) card.

   6) Boot from the 8GB card, make changes, install other softwaare, change the desktop, whatever.

   7) To make an image of that 8GB card that you can restore anytime in the future do the following...
   
.   

   
# TO MAKE AN IMAGE FILE  
   
   1) Boot your Pi with your Master SD-card as above.
   
   2) Put your source SD-card (8GB) in the USB SD reader and insert it in a Pi USB port.
   
   3) Startup Pi-Safe from the menu.  Or in a terminal, type in 'pisafe'
        
   4) Use the menu to select BACKUP, select your SD-card and the image-file a name.
   
   5) Watch your image-file get created, shrunk and compressed automatically.
    
 .
   

# INSTALL

In a terminal window, type in

      
    wget https://raw.githubusercontent.com/RichardMidnight/pi-safe/main/pisafe -O pisafe
    bash pisafe
    
    Then you can select 'tools' 'install' from the menu to install it into your Raspberry Pi menu
    
   
   
# COMPATIBILITY   
Originally developed and tested on Raspberry pi 4 running Raspberry Pi OS Buster.

Also tested on RaspiOS-arm64, Raspberry Pi Desktop, Raspbian Stretch, Ubuntu 20.20 for Rpi, Linux Mint, LMDE.

v1.0.5 Added support for other terminals: lxterminal, gnome-terminal, xfce-terminal, mate-terminal, konsole, xterm, uxterm, qterminal.

V1.0.5 Added support for other text editors: leafpad, mousepad, gedit, kwrite, pluma, featherpad, xed, geany, kate, nano.

V1.1.0 Added support for Manjaro and maybe other Arch versions.
 
   
   
 # REFERENCES
 
Thanks to Raspberry Pi for how to read and write an image file.

Thanks to https://github.com/Drewsif/PiShrink for the PiShrink engine.

Thanks to all the people who posted code snipets on the web.

    
