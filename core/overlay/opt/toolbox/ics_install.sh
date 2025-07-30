#!/usr/bin/env bash
# ICS/SCADA Security Suite installer

set -e

echo "=================================================="
echo "   USBFREEDOM ICS/SCADA Security Suite Setup"
echo "=================================================="
echo

# Function to check internet connectivity
check_internet() {
    echo "[+] Checking Internet connectivity..."
    if ping -c 1 1.1.1.1 >/dev/null 2>&1; then
        echo "[+] Internet connection detected."
        return 0
    else
        echo "[-] No Internet connection. Please connect and try again."
        return 1
    fi
}

# Function to install system dependencies
install_system_deps() {
    echo "[+] Installing system dependencies..."
    sudo apt-get update >/dev/null 2>&1
    sudo apt-get install -y python3-pip python3-dev git build-essential >/dev/null 2>&1
    sudo apt-get install -y wireshark nmap >/dev/null 2>&1
    echo "[+] System dependencies installed"
}

# Function to install Python ICS tools
install_python_ics_tools() {
    echo "[+] Installing Python ICS tools..."
    
    # Core ICS libraries
    pip3 install --user pymodbus scapy >/dev/null 2>&1
    pip3 install --user impacket python-snap7 >/dev/null 2>&1
    
    # Additional protocol libraries
    pip3 install --user pycomm3 cpppo >/dev/null 2>&1  # Ethernet/IP, CIP
    
    echo "[+] Python ICS tools installed"
}

# Function to setup Modbus tools
setup_modbus_tools() {
    echo "[+] Setting up Modbus tools..."
    
    mkdir -p ~/ics-security/tools
    cd ~/ics-security/tools
    
    # Create Modbus scanner
    cat > modbus-scanner.py << 'EOF'
#!/usr/bin/env python3
"""
Simple Modbus TCP scanner and enumerator
Usage: python3 modbus-scanner.py <target_ip> [port]
"""

import sys
import socket
from pymodbus.client.sync import ModbusTcpClient

def scan_modbus(target, port=502):
    print(f"Scanning Modbus TCP on {target}:{port}")
    
    try:
        client = ModbusTcpClient(target, port=port, timeout=3)
        if client.connect():
            print(f"[+] Modbus TCP service detected on {target}:{port}")
            
            # Try to read device identification
            try:
                result = client.read_device_information()
                if result:
                    print(f"[+] Device Information:")
                    for key, value in result.information.items():
                        print(f"    {key}: {value}")
            except:
                print("[-] Could not read device information")
            
            # Try to read some coils
            try:
                result = client.read_coils(0, 10)
                if not result.isError():
                    print(f"[+] Read coils 0-9: {result.bits}")
            except:
                print("[-] Could not read coils")
            
            client.close()
            return True
        else:
            print(f"[-] Could not connect to {target}:{port}")
            return False
    except Exception as e:
        print(f"[-] Error: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 modbus-scanner.py <target_ip> [port]")
        sys.exit(1)
    
    target = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 502
    
    scan_modbus(target, port)
EOF

    chmod +x modbus-scanner.py
    
    # Create Modbus fuzzer
    cat > modbus-fuzzer.py << 'EOF'
#!/usr/bin/env python3
"""
Simple Modbus TCP fuzzer
Usage: python3 modbus-fuzzer.py <target_ip> [port]
WARNING: Use only on systems you own or have permission to test!
"""

import sys
import time
import random
from pymodbus.client.sync import ModbusTcpClient

def fuzz_modbus(target, port=502):
    print(f"Fuzzing Modbus TCP on {target}:{port}")
    print("WARNING: This may cause system instability!")
    
    confirm = input("Continue? (yes/no): ")
    if confirm.lower() != 'yes':
        print("Aborted.")
        return
    
    client = ModbusTcpClient(target, port=port, timeout=1)
    
    if not client.connect():
        print(f"[-] Could not connect to {target}:{port}")
        return
    
    print("[+] Connected, starting fuzzing...")
    
    try:
        for i in range(100):
            try:
                # Random function codes and addresses
                func_code = random.randint(1, 4)
                address = random.randint(0, 1000)
                count = random.randint(1, 100)
                
                if func_code == 1:
                    client.read_coils(address, count)
                elif func_code == 2:
                    client.read_discrete_inputs(address, count)
                elif func_code == 3:
                    client.read_holding_registers(address, count)
                elif func_code == 4:
                    client.read_input_registers(address, count)
                
                print(f"[{i+1}/100] Fuzzed function {func_code}, addr {address}, count {count}")
                time.sleep(0.1)
                
            except Exception as e:
                print(f"[-] Error in iteration {i+1}: {e}")
                
    except KeyboardInterrupt:
        print("\n[!] Fuzzing interrupted by user")
    
    client.close()
    print("[+] Fuzzing complete")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 modbus-fuzzer.py <target_ip> [port]")
        sys.exit(1)
    
    target = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 502
    
    fuzz_modbus(target, port)
EOF

    chmod +x modbus-fuzzer.py
    
    echo "[+] Modbus tools created"
}

# Function to setup Ethernet/IP tools
setup_ethernet_ip_tools() {
    echo "[+] Setting up Ethernet/IP tools..."
    
    cd ~/ics-security/tools
    
    # Create EtherNet/IP scanner
    cat > enip-scanner.py << 'EOF'
#!/usr/bin/env python3
"""
Simple EtherNet/IP scanner
Usage: python3 enip-scanner.py <target_ip>
"""

import sys
import socket
from cpppo.server.enip import client

def scan_enip(target):
    print(f"Scanning EtherNet/IP on {target}:44818")
    
    try:
        # Try to connect and list identity
        via = f"{target}:44818"
        
        with client.connector(host=target, port=44818) as conn:
            if conn:
                print(f"[+] EtherNet/IP service detected on {target}")
                
                # Try to get device identity
                try:
                    response = client.list_identity(via=via)
                    if response:
                        print(f"[+] Device Identity Information:")
                        for item in response:
                            print(f"    {item}")
                except Exception as e:
                    print(f"[-] Could not get identity: {e}")
                
                return True
            else:
                print(f"[-] Could not connect to {target}:44818")
                return False
                
    except Exception as e:
        print(f"[-] Error: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 enip-scanner.py <target_ip>")
        sys.exit(1)
    
    target = sys.argv[1]
    scan_enip(target)
EOF

    chmod +x enip-scanner.py
    
    echo "[+] Ethernet/IP tools created"
}

# Function to setup Wireshark ICS dissectors
setup_wireshark_dissectors() {
    echo "[+] Setting up Wireshark with ICS dissectors..."
    
    # Create Wireshark profile for ICS analysis
    mkdir -p ~/.config/wireshark/profiles/ICS-Analysis
    
    cat > ~/.config/wireshark/profiles/ICS-Analysis/preferences << 'EOF'
# ICS Analysis Wireshark Profile
# Enable relevant protocol dissectors
protocols.modbus: TRUE
protocols.enip: TRUE
protocols.cip: TRUE
protocols.dnp3: TRUE
protocols.iec104: TRUE
protocols.goose: TRUE
protocols.sv: TRUE

# Display filters for common ICS protocols
gui.filter_expressions.label.modbus: Modbus
gui.filter_expressions.expr.modbus: modbus
gui.filter_expressions.label.enip: EtherNet/IP
gui.filter_expressions.expr.enip: enip or cip
gui.filter_expressions.label.dnp3: DNP3
gui.filter_expressions.expr.dnp3: dnp3
EOF

    echo "[+] Wireshark ICS profile created"
}

# Function to create ICS analysis workspace
create_workspace() {
    echo "[+] Creating ICS security workspace..."
    
    mkdir -p ~/ics-security/{tools,captures,reports,scripts}
    
    # Create network discovery script
    cat > ~/ics-security/scripts/ics-discovery.sh << 'EOF'
#!/bin/bash
# ICS Network Discovery Script

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <network_range>"
    echo "Example: $0 192.168.1.0/24"
    exit 1
fi

NETWORK="$1"

echo "=== ICS Network Discovery ==="
echo "Target: $NETWORK"
echo "Date: $(date)"
echo

echo "=== Port Scanning for Common ICS Protocols ==="
echo "Scanning for Modbus TCP (502)..."
nmap -p 502 --open "$NETWORK" | grep -E "Nmap scan report|502/tcp"

echo
echo "Scanning for EtherNet/IP (44818)..."
nmap -p 44818 --open "$NETWORK" | grep -E "Nmap scan report|44818/tcp"

echo
echo "Scanning for DNP3 (20000)..."
nmap -p 20000 --open "$NETWORK" | grep -E "Nmap scan report|20000/tcp"

echo
echo "Scanning for BACnet (47808)..."
nmap -p 47808 --open "$NETWORK" | grep -E "Nmap scan report|47808/tcp"

echo
echo "=== Service Detection ==="
nmap -sV -p 102,502,2404,20000,44818,47808 "$NETWORK"

echo
echo "Discovery complete."
EOF

    chmod +x ~/ics-security/scripts/ics-discovery.sh
    
    echo "[+] ICS workspace created"
}

# Function to show completion message
show_completion() {
    echo
    echo "=================================================="
    echo "   ICS/SCADA Security Suite Setup Complete!"
    echo "=================================================="
    echo
    echo "Installed tools:"
    echo "  • Python ICS libraries (pymodbus, pycomm3, python-snap7)"
    echo "  • Custom Modbus scanner and fuzzer"
    echo "  • EtherNet/IP scanner"
    echo "  • Wireshark with ICS dissectors"
    echo "  • Network discovery scripts"
    echo
    echo "Workspace: ~/ics-security/"
    echo
    echo "Quick start commands:"
    echo "  ~/ics-security/scripts/ics-discovery.sh 192.168.1.0/24  # Network discovery"
    echo "  python3 ~/ics-security/tools/modbus-scanner.py 192.168.1.10  # Modbus scan"
    echo "  python3 ~/ics-security/tools/enip-scanner.py 192.168.1.10    # EtherNet/IP scan"
    echo "  wireshark -k -i eth0 -f 'port 502'                           # Modbus capture"
    echo
    echo "Supported protocols:"
    echo "  • Modbus TCP (port 502)"
    echo "  • EtherNet/IP (port 44818)"
    echo "  • DNP3 (port 20000)"
    echo "  • IEC 61850 GOOSE/SV"
    echo "  • BACnet (port 47808)"
    echo
    echo "⚠️  CRITICAL WARNING:"
    echo "   Only use these tools on systems you own or have explicit"
    echo "   permission to test. ICS systems control critical infrastructure"
    echo "   and unauthorized testing can cause serious damage or safety risks!"
    echo
}

# Main execution
main() {
    if ! check_internet; then
        exit 1
    fi
    
    install_system_deps
    install_python_ics_tools
    setup_modbus_tools
    setup_ethernet_ip_tools
    setup_wireshark_dissectors
    create_workspace
    show_completion
}

# Run main function
main "$@"
