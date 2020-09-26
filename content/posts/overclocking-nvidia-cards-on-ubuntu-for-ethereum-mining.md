---
title: "Overclocking NVIDIA cards on Ubuntu for Ethereum mining"
Description: "A step-by-step guide to increase the mining hash rate of your NVIDIA cards"
date: 2020-09-25T17:55:04-05:00
showtoc: false
---
# Overview

Once you've built your Ethereum mining rigs and they've been operational for a while, then you may desire to overclock the machines in order to boost the performance of each rig.  Overclocking GPUs on Linux is a bit more involved than Windows, but it is still possible.

There are 3 main steps to overclocking your graphics cards:
1. [Install and configure X org](#install-and-configure-xorg)
2. [Reinstall the NVIDIA driver](#reinstall-the-nvidia-driver)
3. [Install a service to automatically overclock the GPUs at startup](#install-a-service-to-automatically-overclock-the-gpus-at-startup)

# Install and configure Xorg 

If you followed our previous guide to [install Ubuntu Server LTS for mining Ethereum](/posts/building-an-ethereum-mining-rig-with-ubuntu-and-nvidia), then you will not have an X server installed on your system.  In order to overclock NVIDIA cards on Ubuntu you need to install the X server from Xorg, so that we can change the configuration of the graphics cards to accept the parameters for overclocking using nvidia-settings. This is a required step as even though the nvidia-settings program is accessible through the CLI, it still expects to be able to connect to a display run by an X server.

Note: If you installed the desktop version of Ubuntu, then it will already come with a window manager Gnome, KDE, XFCE, etc. and so X org will already be included by default and you can skip to [Update the Xorg configuration](#update-the-xorg-configuration).  Just remember that when you install the service to leave off the -x option.

### Install the packages xorg and openbox

To install Xorg and Openbox run the following command:
```
sudo apt-get install xorg openbox
```
Note: We are installing openbox here, so that the `startx` command functions correctly.  Without openbox installed, an attempt will be made to start the X server, but then startx will terminate a few seconds later due to not being able to connect to the display.

### Update the Xorg configuration

Next create an Xorg configuration file with all GPUs enabled:
```
sudo nvidia-xconfig --enable-all-gpus
```

Now edit the Xorg configuration file and set the Coolbits option for each graphics card entry:
```
sudo vi /etc/X11/xorg.conf
```

The Coolbits option is a bitmask integer value that turns on/off the ability to tweak certain features on the card.  Below is a reference of what each of the values mean.  You can also read about them on [NVIDIA's site](http://download.nvidia.com/XFree86/Linux-x86_64/430.14/README/xconfigoptions.html#Coolbits) as well.

Value | Description
---   | ---
2     | The NVIDIA driver will attempt to initialize SLI when using GPUs with different amounts of video memory
4     | The nvidia-settings Thermal Monitor page will allow configuration of GPU fan speed, on graphics boards with programmable fan capability
8     | The PowerMizer page in the nvidia-settings control panel will display a table that allows setting per-clock domain and per-performance level offsets to apply to clock values. This is allowed on certain GeForce GPUs. Not all clock domains or performance levels may be modified. On GPUs based on the Pascal architecture the offset is applied to all performance levels.
16    | The nvidia-settings command line interface allows setting GPU overvoltage. This is allowed on certain GeForce GPUs.


We will be setting the value of "Coolbits" to "28" (4+8+16), to enable all features except SLI.

When editing the file, each graphics card entry will have a "Device" section.  This is where you need to add the Coolbits option.  You will also need to add the option AllowEmptyInitialConfiguration, as we won't be setting any screen geometry, as typically you want the machine to be able to operate headless.  

The options will look as follows:
```
    Option         "Coolbits" "28"
    Option         "AllowEmptyInitialConfiguration"
```

After editing, each device section should look similar to the following:
```
Section "Device"
    Identifier     "Device0"
    Driver         "nvidia"
    VendorName     "NVIDIA Corporation"
    BoardName      "GeForce GTX 1070"
    BusID          "PCI:1:0:0"
    Option         "Coolbits" "28"
    Option         "AllowEmptyInitialConfiguration"
EndSection
```

Remember you should do this for each "Device" section and you should have the same number of "Device" sections as you have graphics cards in the rig.

Once you have finished editing, save and exit the file.

# Reinstall the NVIDIA driver

Before reinstalling the NVIDIA driver you need to purge any old nvidia drivers that might have been installed by default.  This is important, so that the proprietary driver is found correctly when *startx* is invoked after reboot.  If this is not done, you may not be able to bring up the Xserver with the *startx* command.

To purge your system of any old nvidia drivers, run the following command:
```
sudo apt-get purge nvidia*

## Remove any old NVIDIA drivers
```

Now, rerun the NVIDIA driver installation.  If you do not remember how to do that, then take a look at our first blog post when we built the mining rigs.  The command should be similar to the following:
```
sudo CC=/usr/local/bin/gcc ./NVIDIA-Linux-x86_64-430.14.run --kernel-source-path=/usr/src/linux-4.15.0
```

During the installation NVIDIA may prompt you as follows:

> An incomplete installation of libglvnd was found.  All of the essential libglvnd libraries are present,
> but one or more optional components are missing.  Do you want to install a full copy of libglvnd?
> This will overwrite any existing libglvnd libraries.

Select **Install and overwrite existing files**

Once the driver build and installation completes, the installer will prompt you to overwrite the existing
xorg.conf file.

> Would you like to run the nvidia-xconfig utility to automatically update your X coniguration file
> so that the NVIDIA X driver will be used when you restart X?  Any pre-existing X configuration file
> will be backed up.

Select **Yes** to overwrite the X configuration file.


# Install a service to automatically overclock the GPUs at startup

At this point, the graphics cards can be overclocked if you were to run *startx* and then manually invoke *nvidia-settings*.  Rather than doing this everytime we boot the system, we will install a script and service to make management easier.  

The script is [nvidia-overclock.sh](https://github.com/plyint/nvidia-overclock.sh)

You can download it direct from the repo by running the following curl command:
```
sudo curl https://raw.githubusercontent.com/plyint/nvidia-overclock.sh/master/nvidia-overclock.sh -o /usr/local/bin/nvidia-overclock.sh
```

Note: As an alternative to using the script approach, you could also set the values inside of the *.xinitrc* file that is run when an Xserver starts.  The script though has a few advantages in the simple mining use case:

- Quickly update values and rerun without reloading X (Easier to find good overclocking values)
- Logging, so you can see the overclock values that get set at boot
- Isolation from any other X activites

Once the script is downloaded you need to mark the script as executable and install the service:
```
sudo chmod 755 /usr/local/bin/nvidia-overclock.sh
sudo /usr/local/bin/nvidia-overclock.sh install-svc -x
```

Note: We use the -x option, so that the *startx* command is invoked to start X windows automatically.  If you don't want or need this, then just omit this option.

Finally, you will probably want to update the GPU overclock values (unless you have GTX 1070 cards) in the *nvidia-overclock.sh* script. Set the values for the *Graphics Clock Offset* and *Memory Transfer Rate Offset* to whatever you can find online that has worked for other people with the same card as you.  


```
overclock () {
  # The following default overclock values for the NVIDIA GTX 1070 
  # were found on average to be stable:
  # - Graphics Clock       = 100
  # - Memory Transfer Rate = 1300
  #
  # Adjust these values for each card as needed.  Some cards are more 
  # unstable than others and will only tolerate less overclocking.  Other
  # cards might tolerate above normal overclocking. If you are unsure of the 
  # starting values to use for your graphics cards, try searching online
  # for what other people with your same graphics cards have found to be stable.
  #
  # Note: The lines below were used to configure a system with 6 graphics cards.
  # You will neeed to add/remove lines based on the number of graphics cards in 
  # your particular system.
  log "Calling nvidia-settings to overclock GPU(s).."
  log "$(nvidia-settings -c :0 -a '[gpu:0]/GPUGraphicsClockOffset[3]=100' -a '[gpu:0]/GPUMemoryTransferRateOffset[3]=1300')"
  log "$(nvidia-settings -c :0 -a '[gpu:1]/GPUGraphicsClockOffset[3]=100' -a '[gpu:1]/GPUMemoryTransferRateOffset[3]=1300')"
  log "$(nvidia-settings -c :0 -a '[gpu:2]/GPUGraphicsClockOffset[3]=100' -a '[gpu:2]/GPUMemoryTransferRateOffset[3]=1300')"
  log "$(nvidia-settings -c :0 -a '[gpu:3]/GPUGraphicsClockOffset[3]=100' -a '[gpu:3]/GPUMemoryTransferRateOffset[3]=1300')"
  log "$(nvidia-settings -c :0 -a '[gpu:4]/GPUGraphicsClockOffset[3]=100' -a '[gpu:4]/GPUMemoryTransferRateOffset[3]=1300')"
  log "$(nvidia-settings -c :0 -a '[gpu:5]/GPUGraphicsClockOffset[3]=100' -a '[gpu:5]/GPUMemoryTransferRateOffset[3]=1300')"
}
```

Note: If you are not sure what values to use, you can start off with the defaults and then adjust as you run the miner.  If the settings are bad you will see the card drop off from the system or stop mining.  If this happens just change the values and rerun the script again.

You can quickly rerun the script again, without rebooting or starting an Xserver by running the following command:
```
/usr/local/bin/nvidia-overclock.sh overclock
```

Once you are satisfied with your settings, you can reboot the system and test them out.
```
sudo reboot
```

That's it.  The system should now automatically boot and overclock the cards for you.  The screen will likely show as all black for you once the system boots.  If you have a monitor/keyboard attached and want to login directly to the system, you will need to switch to an available virtual terminal (e.g. tty3).  To do this hit Ctrl+Alt+F3(the function key represents the tty number) to jump to virtual terminal 3.  You should now have a login prompt and can login as usual.

Happy mining! :)