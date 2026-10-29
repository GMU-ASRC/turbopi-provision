# GMU-ASRC Provisioning Scripts for Hiwonder TurboPi

This repository contains scripts for adding GMU-ASRC drivers and services to
a Raspberry Pi-equipped Hiwonder TurboPi.

> [!IMPORTANT]
> This is the ASRC BRANCH!  
> Please see the [wiki](https://github.com/GMU-ASRC/turbopi-provision/wiki/Branches) for a list of install URLs for the different flavors of our software.


Part of the GMU-ASRC TurboPi cinematic universe:
* [Provision](https://github.com/GMU-ASRC/turbopi-provision) (You are here)
* [Driver](https://github.com/GMU-ASRC/turbopi-driver)
* [Core Services](https://github.com/GMU-ASRC/turbopi-coreservices)

Research-related (not installed by main branch provision scripts):
* [TurboPi management and simulations](https://github.com/GMU-ASRC/turbopi)
* [Managed Home Directory](https://github.com/GMU-ASRC/turbopi-root)

## Minimum requirements

This software has only been tested on the following hardware and software setup:
* Raspberry Pi **4** Model B
* Raspberry Pi OS (64-bit) **Trixie** (Debian 13)
* Hiwonder TurboPi with Mecanum wheels
* Hiwonder RasAdapter V3.6 *or earlier* (for Pi 4B)  
  Note: Earlier versions of the RasAdapter may not have the silkscreened
  hardware revision label.

# Numbering

All the Turbopis in the lab are numbered. When you build and commission a new Turbopi, please serialize it, i.e. give it the next largest unused number. Make sure to put the right sticker on!

> [!NOTE]
> The number also needs to be set in software. This can be done in either Step 1 or Step 7 below.

# Installation

1. Use the [Raspberry Pi Imager](https://www.raspberrypi.com/software/) to flash the latest Raspberry Pi OS image to a microSD card.

    Use the following settings:
    * Device: Raspberry Pi 4
    * Operating System: Raspberry Pi OS (64-bit) Debian Trixie (recommended)
    * Customization:
      * Hostname: Set the unique robot name here.
        * Either set the number, like `turbopi-01`,
        or set as `turbopi-00` or `raspberrypi` to get prompted to set the number in the script in step 7.
      * Wi-Fi: If you want to connect to WiFi, enter the WiFi credentials here.
        * The script will set up a static IP for the robot using the hostname in step 7. If you give the robot a `turbopi-nn` hostname where the last two digits are not `00`, then it will set the IP without prompting you.
      * Enable SSH: Yes
          * Authentication mechanism: <kbd><samp>Use password authentication</samp></kbd>
> [!WARNING]
> The hostname and static IP of the robot must be unique. If two robots with the same name or IP address connect to the same network, the hostname/address collision may cause network connection issues that persist for a short while even after the robots are turned off.
2. Insert the microSD card into the Raspberry Pi. You'll need to undo the four screws on the metal ultrasonic sensor cover to access the micro SD card on the Raspberry Pi.
    
  > [!TIP]
  > The micro SD card slot is on the bottom of the Raspberry Pi and may be hard to see.
  > When inserting the micro SD card, the gold contacts should face upwards, towards the green PCB. Be gentle.

3. Insert two 18650 batteries into the bottom of the TurboPi. Make sure to heed the polarity indicator in the battery tray. Once inserted, we recommend using a battery cover.
4. Turn on the TurboPi. There are two switches that both must be in the "on" position:
    * The battery tray under the TurboPi has a switch.
    * The RasAdapter (black board under the metal shield) has a switch. `ON` is towards the USB ports, `OFF` is towards the front of the TurboPi.
    * Once on, the ultrasonic sensor should turn blue and remain that way. Unlike HiWonder's included OS image, the drivers and services are not installed yet, so the ultrasonic sensor LEDs will not turn off and there is no beep to indicate that the Pi has booted up.
5. Connect the Pi via ethernet or WiFi (previously configured in step 1).
6. SSH into the pi using the username and hostname you setup in step 1:

    <kbd>ssh <samp><kbd>USERNAME</kbd></samp>@<samp><kbd>HOSTNAME</kbd></samp>.local</kbd>

    Note: Depending on your router, you may need to remove the `.local` suffix from the hostname. (networks with MDNS/Bonjour support will work with `.local`, but some routers will support automatic hostname registration without the suffix. You can also try `.lan`).  
    MacOS users will not be able to connect to the Pi via SSH without a suffix.
7. Run the following commands to install the GMU-ASRC drivers and services:

    ```bash
    curl -sSL https://raw.githubusercontent.com/GMU-ASRC/turbopi-provision/main/webinstall.sh | bash -s -- -b asrc --home-branch asrc
    ```

  > [!IMPORTANT]
  > The above link is for the ASRC BRANCH!  
  > Please see the [wiki](https://github.com/GMU-ASRC/turbopi-provision/wiki/Branches) for a list of install URLs for the different flavors of our software.
