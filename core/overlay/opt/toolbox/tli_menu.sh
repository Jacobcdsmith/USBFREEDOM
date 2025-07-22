#!/usr/bin/env bash

# tli_menu.sh - USBFREEDOM ASCII CLI Portal

ascii_art="
 __    __  _____  ____  ______  ______  _____  ______  ______  __  __
|  |  |  ||  ___||    \\|   ___||   ___||  _  ||   ___||   ___||  ||  |
|  |__|  ||  ___||     \\  ___| |  ___| | |_| ||  ___| |  ___| |  ||  |
|_______/ |_____||__|\\__\\_____||_____||_____||_____  ||_____  |______|
                                                        |_____|       
"

menu_items=(
  "1) Penetration Testing Kit (Kali-based)"
  "2) Malware Analysis Lab (REMnux-based)"
  "3) Data Science Workbench (Ubuntu LTS)"
  "4) Mobile Development SDK (Manjaro ARM)"
  "5) SDR Communications Kit (Kali-SDR)"
  "6) Firmware Analysis Toolkit (Debian)"
  "7) ICS/SCADA Security Suite (Kali ICS)"
  "8) OS Installation Media (Ventoy Multiboot)"
  "Q) Quit"
)

clear
echo -e "\e[1;36m$ascii_art\e[0m"
echo "Welcome to USBFREEDOM Toolkit"
echo "Select an option to begin:"
echo

for item in "${menu_items[@]}"; do
  echo "  $item"
done

echo
read -p "Enter your choice: " choice

case "$choice" in
  1)
    echo "Launching Penetration Testing Kit..."
    bash /opt/toolbox/pentest_install.sh
    ;;
  2)
    echo "Launching Malware Analysis Lab..."
    bash /opt/toolbox/malware_install.sh
    ;;
  3)
    echo "Launching Data Science Workbench..."
    bash /opt/toolbox/datasci_install.sh
    ;;
  4)
    echo "Launching Mobile Development SDK..."
    bash /opt/toolbox/mobiledev_install.sh
    ;;
  5)
    echo "Launching SDR Communications Kit..."
    bash /opt/toolbox/sdr_install.sh
    ;;
  6)
    echo "Launching Firmware Analysis Toolkit..."
    bash /opt/toolbox/firmware_install.sh
    ;;
  7)
    echo "Launching ICS/SCADA Security Suite..."
    bash /opt/toolbox/ics_install.sh
    ;;
  8)
    echo "Launching OS Installation Media..."
    bash /opt/toolbox/osinstaller.sh
    ;;
  [Qq])
    echo "Goodbye!"
    exit 0
    ;;
  *)
    echo "Invalid selection."
    sleep 2
    exec "$0"
    ;;
esac
