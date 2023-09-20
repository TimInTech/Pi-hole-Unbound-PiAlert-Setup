# Pi-hole & Pi.Alert Installation Guide for Raspberry Pi

## Introduction

Dive into the world of network monitoring and ad-blocking with Pi-hole and Pi.Alert on your Raspberry Pi. This guide will walk you through the installation process and help you set up these tools for optimal network protection and visibility.

## Prerequisites:

- A Raspberry Pi running Debian OS (64-Bit) with Kernel version 6.1.47-v8+.
- An active internet connection.

## Step 1: Installing Pi-hole

1. **Update Your System**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Install Pi-hole**:
   ```bash
   curl -sSL https://install.pi-hole.net | bash
   ```

3. Follow the on-screen instructions to configure Pi-hole.

## Step 2: Installing Pi.Alert

1. **Download the Pi.Alert Installation Script**:
   ```bash
   bash -c "$(wget -qLO - https://github.com/leiweibau/Pi.Alert/raw/main/install/pialert_install.sh)"
   ```

2. Follow the on-screen instructions to configure Pi.Alert.

## Step 3: Configuring Pi.Alert for Single Network Monitoring

1. **Edit the Pi.Alert Configuration File**:
   ```bash
   nano /home/pi/pialert/config.php
   ```

2. Locate the `SCAN_SUBNETS` section and add your desired network:
   ```bash
   SCAN_SUBNETS = [ '192.168.0.1/24' ]
   ```

3. Save the file and exit the editor.

## Optional: Configuring Pi.Alert for Dual Network Monitoring

1. **Edit the Pi.Alert Configuration File**:
   ```bash
   nano /home/pi/pialert/config.php
   ```

2. Locate the `SCAN_SUBNETS` section and add your desired networks:
   ```bash
   SCAN_SUBNETS = [ '192.168.0.1/24', '192.168.178.0/24' ]
   ```

3. Save the file and exit the editor.

---

**Note**: Always ensure to check the official documentation and repositories for the most up-to-date installation instructions and best practices.
