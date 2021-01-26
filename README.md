# PiSafe  -  Raspberry Pi imaging app

Backup and Restore Raspberry Pi SD cards ... easily create image files

 - Easily make compressed images of your Raspberry Pi.
 
 - Easily restore images to an SD card.

 - Read an image-file from an sd card.

 - Write an image-file to an sd card.

 - Works entirely on a Raspberry Pi in terminal.  No Windows or Mac needed. 
 
 - Creates a compressed image-file that will resize to fill the new card it is put on (thanks to PiShrink!).
 
 - Supports .img .zip .xz and .gz file formats.
 
 - Supports all USB storage.
 
 - Supports USB boot (tries to hide the boot disk).
 
.
 
# SETUP
 
   1) Install Raspberry PI OS on an SD card that is large enought to hold some SD image-files.  32GB or 64GB will do.  This is your Master SD-card.
   
   2) Install Pi-Safe as described below.
   
   3) You will need a USB-SD reader for your source SD-card.
   
   4) You will need some SD cards.  Use as small of an SD-card as you can because the entire card has to be read in before it is shrunk and compressed.  I have been using Sandisk Industrial 8GB cards.
   
.   

   
# TO MAKE AN IMAGE FILE  
   
   1) Boot your Pi with your Master SD-card as above.
   
   2) Put your source SD-card in the USB SD reader and insert it in a Pi USB port.
   
   3) Startup pisafe from the menu.  Or in a terminal, type in 'pisafe'
        
   5) Use the menu to select your SD-card and an image-file-name.
   
   6) Watch your image-file get created!
   
 .
   

# INSTALL

In a terminal window, type in

    wget https://raw.githubusercontent.com/RichardMidnight/pi-safe/main/pisafe
    bash pisafe
    
    Then you can select 'install' from the menu to install it in your Raspberry Pi menu
    
    
    beta ver: 
    
    wget https://raw.githubusercontent.com/RichardMidnight/pi-safe/main/pisafe-beta
    bash pisafe-beta
   
    
