# DNSTT Launcher

<p align="center">
  <img src="bin/icon.ico" alt="DNSTT Launcher Icon" width="128">
</p>

<p align="center">
  <strong>A professional GUI for the DNSTT tunnel client.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/github/v/release/MinitorMHS/dnstt-launcher?style=flat-square" alt="Latest Release">
  <img src="https://img.shields.io/github/downloads/MinitorMHS/dnstt-launcher/total?style=flat-square&color=green" alt="Total Downloads">
  <img src="https://img.shields.io/github/license/MinitorMHS/dnstt-launcher?style=flat-square" alt="License">
  <img src="https://komarev.com/ghpvc/?username=MinitorMHS&repo=dnstt-launcher&label=Project%20Views&color=blue&style=flat-square" alt="Project Views">
</p>

---

## ⚠️ Important Note: Tunnel vs. VPN

**DNSTT Launcher is a DNS Tunneling tool, not a standalone VPN.** This project provides the transport layer required to bypass certain network restrictions. To achieve full system encryption or internet browsing capabilities, you **must** use this launcher in conjunction with a proxy (like a socks in telegram) or VPN client.

### Recommended Clients:
* **[v2rayN](https://github.com/2dust/v2rayN)**: A powerful GUI client for Windows supporting V2Ray, Xray, and Trove protocols.
* **[Throne](https://github.com/Throne-Project/Throne)**: A specialized client designed for advanced tunneling and proxy management.
* **[Clash / Clash Meta](https://github.com/MetaCubeX/Clash.Meta)**: A rule-based tunnel in Go with support for multiple protocols.

---

## 📖 Overview

DNSTT Launcher provides a user-friendly Windows interface for managing and launching the DNSTT client. This launcher is designed to work with the **[official DNSTT client](https://www.bamsoftware.com/software/dnstt/)**, ensuring you are using the most secure and up-to-date tunneling technology available.

## ✨ Key Features

* **Pre-configured DNS List**: Includes a curated selection of reliable DNS servers such as Google, Cloudflare, and Rostelecom.
* **Custom Server Management**: Add, edit, or delete private DNS servers directly through the interface.
* **Persistent Settings**: Saves your Tunnel Domain, Public Key, and Listen Host configurations locally.
* **Auto-Restart System**: Built-in timer to automatically restart the tunnel at specified intervals (Seconds, Minutes, or Hours) for maximum uptime.
* **System Tray Integration**: Minimize the application to the tray to keep it running in the background.
* **Native Architecture Support**: Automatically deploys the correct version for x86, x64, or ARM64 systems via the installer.

## 🚀 Getting Started

### Installation
1.  Download the latest `DNSTT_Launcher_Setup.exe` from the [Releases](https://github.com/MinitorMHS/dnstt-launcher/releases) page.
2.  Run the installer. It will install the application and create a desktop shortcut (If you see Unknown publisher warning simply click on more info and then Run anyway)
3.  The setup process automatically includes the necessary `dnstt-client-windows.exe` binaries.

### Configuration
1.  Launch the application.
2.  Click **Settings** to configure your **Tunnel Domain**, **Public Key (Hex)**, and **Local Port**.
3.  Select a DNS server from the dropdown and click **Start**.

## 🛠 Technical Details

* **Language**: PowerShell (GUI Backend).
* **Launcher**: VBScript (for silent execution).
* **Build Source**: Uses the official [DNSTT repository](https://www.bamsoftware.com/software/dnstt/) for client binaries.

## ⚖️ License

This project is licensed under the GNU GENERAL PUBLIC LICENSE - see the [LICENSE](LICENSE) file for details.

---
<p align="center">Developed by <a href="https://github.com/MinitorMHS">Minitor</a></p>
