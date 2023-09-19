# Pi-hole-Pi.Alert-Installation-

Pi-hole &amp; Pi.Alert Installation on Raspberry Pi
🚀 Pi-hole & Pi.Alert on Raspberry Pi: The Ultimate Network Toolset!

Dive into the world of network monitoring and ad-blocking with this comprehensive guide to installing Pi-hole and Pi.Alert on a Raspberry Pi. With these tools, you can not only block unwanted ads but also monitor your network and ensure everything is running smoothly. This repository provides step-by-step instructions to guide you through the entire process. Whether you're new to networking or a seasoned pro, these tools will elevate your networking experience to the next level. 🌐

Features:

    🛡️ Block unwanted ads at the network level with Pi-hole.
    🖥️ Monitor devices on your network and detect unusual activities with Pi.Alert.
    🌍 Support for monitoring two separate networks.
    💡 Easy-to-follow installation instructions.

Created by: ==TIM.©.B==
Motto: "Gummiflip - Because technology should be flexible and fun!"

Pi-hole & Pi.Alert Installation on Raspberry Pi

This repository provides a comprehensive guide on setting up Pi-hole and Pi.Alert on a Raspberry Pi for network monitoring and ad-blocking. Dive deep into the world of network management with these powerful tools.
Prerequisites

    Raspberry Pi running Debian OS (64-bit) with Kernel Version 6.1.47-v8+.
    Active internet connection.

Step 1: Installing Pi-hole

    Update your system:

    bash

sudo apt update && sudo apt upgrade -y

Install Pi-hole:

bash

    curl -sSL https://install.pi-hole.net | bash

    Follow the on-screen instructions to configure Pi-hole.

Step 2: Installing Pi.Alert

    Download the Pi.Alert installation script:

    bash

wget https://raw.githubusercontent.com/leiweibau/Pi.Alert/main/install/pialert_install.sh

Make the script executable:

bash

chmod +x pialert_install.sh

Execute the script:

bash

    ./pialert_install.sh

    Follow the on-screen instructions to configure Pi.Alert.

Step 3: Configuring Pi.Alert for Monitoring Two Networks

    Edit the Pi.Alert configuration file:

    bash

nano /home/pi/pialert/config.php

Locate the SCAN_SUBNETS section and add the desired networks:

bash

SCAN_SUBNETS = [ '192.168.0.1/24', '192.168.178.0/24' ]

Save the file and exit the editor.

Restart Pi.Alert:

bash

    (Instructions to restart Pi.Alert, if available)

Updates

To keep your system and installed software up-to-date, regularly execute the following commands:

    Update your system:

    bash

sudo apt update && sudo apt upgrade -y

Update Pi-hole:

bash

pihole -up

Update Pi.Alert:

bash

    (Instructions to update Pi.Alert, if available)

For any questions or issues, please open an issue in this repository.
