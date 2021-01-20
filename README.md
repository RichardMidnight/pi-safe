# Pi-Safe
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
   
   3) Open a terminal window.
   
   4) Change to the 'Downloads' folder (optional).
   
    cd Downloads
   
   4) Type in the command below to see the name of the SD-device.  If it is the only one in, it should be 'sda'.
  
     pisafe list
         
   4)  Type in the command below to start reading the SD-card to an image-file
   
      pisafe read
        
   5) Follow the prompts to enter the SD-device name (probably 'sda') and the image-file-name you want to use.
   
   6) Watch your image-file get created!
   
 .
   

# INSTALL

In a terminal window, type in

    wget https://raw.githubusercontent.com/RichardMidnight/pi-safe/main/pisafe
    bash pisafe
    Then you can select 'install' from the menu
    
    
    beta ver: 
    
    wget https://raw.githubusercontent.com/RichardMidnight/pi-safe/main/pisafe-beta
    bash pisafe-beta
   
.

# EXAMPLES

List available SD-cards and image-files

     pisafe list 
     
To create an image-file from your SD-card in 'sda'

     pisafe backup sda newimage.zip
     
To write an image-file to an SD-card in 'sda'

    pisafe restore newimage.zip sda
    
    
.

# SAMPLE SESSION CREATING AN IMAGE FILE
