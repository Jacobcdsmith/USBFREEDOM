#!/usr/bin/env bash
# SDR Communications Kit (Kali-SDR) installer

set -e

echo "=================================================="
echo "   USBFREEDOM SDR Communications Kit Setup"
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
    sudo apt-get install -y build-essential cmake git python3-pip >/dev/null 2>&1
    echo "[+] System dependencies installed"
}

# Function to install core SDR tools
install_sdr_tools() {
    echo "[+] Installing core SDR tools..."
    
    # Install GNU Radio
    echo "  Installing GNU Radio..."
    sudo apt-get install -y gnuradio gnuradio-dev >/dev/null 2>&1
    
    # Install GQRX SDR
    echo "  Installing GQRX..."
    sudo apt-get install -y gqrx-sdr >/dev/null 2>&1
    
    # Install RTL-SDR tools
    echo "  Installing RTL-SDR utilities..."
    sudo apt-get install -y rtl-sdr librtlsdr-dev >/dev/null 2>&1
    
    # Install HackRF tools
    echo "  Installing HackRF utilities..."
    sudo apt-get install -y hackrf libhackrf-dev >/dev/null 2>&1
    
    # Install additional SDR tools
    echo "  Installing additional tools..."
    sudo apt-get install -y airspy gr-osmosdr kalibrate-rtl multimon-ng >/dev/null 2>&1
    
    echo "[+] Core SDR tools installed"
}

# Function to install Python SDR libraries
install_python_sdr() {
    echo "[+] Installing Python SDR libraries..."
    
    pip3 install --user pyrtlsdr scipy numpy matplotlib >/dev/null 2>&1
    pip3 install --user gnuradio >/dev/null 2>&1 || echo "  Note: GNU Radio Python may already be system-installed"
    
    echo "[+] Python SDR libraries installed"
}

# Function to setup udev rules for SDR devices
setup_udev_rules() {
    echo "[+] Setting up udev rules for SDR devices..."
    
    # RTL-SDR rules
    sudo tee /etc/udev/rules.d/20-rtlsdr.rules > /dev/null << 'EOF'
# RTL-SDR
SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2832", GROUP="plugdev", MODE="0666", SYMLINK+="rtl_sdr"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2838", GROUP="plugdev", MODE="0666", SYMLINK+="rtl_sdr"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0413", ATTRS{idProduct}=="6001", GROUP="plugdev", MODE="0666", SYMLINK+="rtl_sdr"
EOF

    # HackRF rules
    sudo tee /etc/udev/rules.d/53-hackrf.rules > /dev/null << 'EOF'
# HackRF
ATTR{idVendor}=="1d50", ATTR{idProduct}=="6089", SYMLINK+="hackrf-one-%k", MODE="660", GROUP="plugdev"
EOF

    # Add user to plugdev group
    sudo usermod -a -G plugdev $USER
    
    # Reload udev rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    
    echo "[+] Udev rules configured"
}

# Function to create example flow graphs
create_examples() {
    echo "[+] Creating example flow graphs and scripts..."
    
    mkdir -p ~/sdr-projects/{flowgraphs,scripts,captures}
    
    # Create simple FM receiver Python script
    cat > ~/sdr-projects/scripts/simple_fm_receiver.py << 'EOF'
#!/usr/bin/env python3
"""
Simple FM Radio Receiver using RTL-SDR
Usage: python3 simple_fm_receiver.py [frequency_in_MHz]
"""

import sys
from gnuradio import gr, blocks, audio, analog, filter
from gnuradio.filter import firdes
import osmosdr

class SimpleFMReceiver(gr.top_block):
    def __init__(self, frequency=100.1e6):
        gr.top_block.__init__(self, "Simple FM Receiver")
        
        # Variables
        self.samp_rate = samp_rate = 2000000
        self.freq = frequency
        
        # Blocks
        self.osmosdr_source = osmosdr.source(args="numchan=1")
        self.osmosdr_source.set_sample_rate(samp_rate)
        self.osmosdr_source.set_center_freq(self.freq, 0)
        self.osmosdr_source.set_freq_corr(0, 0)
        self.osmosdr_source.set_gain(20, 0)
        
        # Low pass filter
        self.lpf = filter.fir_filter_ccf(
            10, firdes.low_pass(1, samp_rate, 100000, 10000))
        
        # FM demodulator
        self.fm_demod = analog.wfm_rcv(
            quad_rate=samp_rate//10,
            audio_decimation=4,
        )
        
        # Audio sink
        self.audio_sink = audio.sink(48000, "", True)
        
        # Connections
        self.connect((self.osmosdr_source, 0), (self.lpf, 0))
        self.connect((self.lpf, 0), (self.fm_demod, 0))
        self.connect((self.fm_demod, 0), (self.audio_sink, 0))

if __name__ == '__main__':
    freq = 100.1e6  # Default frequency
    if len(sys.argv) > 1:
        freq = float(sys.argv[1]) * 1e6
    
    print(f"Starting FM receiver on {freq/1e6:.1f} MHz")
    print("Press Ctrl+C to stop")
    
    tb = SimpleFMReceiver(freq)
    try:
        tb.start()
        tb.wait()
    except KeyboardInterrupt:
        print("\nShutting down...")
        tb.stop()
        tb.wait()
EOF

    chmod +x ~/sdr-projects/scripts/simple_fm_receiver.py
    
    # Create RTL-SDR test script
    cat > ~/sdr-projects/scripts/test_rtlsdr.py << 'EOF'
#!/usr/bin/env python3
"""
Test RTL-SDR connectivity and capture some samples
"""

try:
    from rtlsdr import RtlSdr
    import numpy as np
    import matplotlib.pyplot as plt
    
    # Initialize RTL-SDR
    sdr = RtlSdr()
    sdr.sample_rate = 2.048e6
    sdr.center_freq = 100e6
    sdr.gain = 'auto'
    
    print(f"RTL-SDR Info:")
    print(f"  Sample Rate: {sdr.sample_rate/1e6:.2f} MHz")
    print(f"  Center Freq: {sdr.center_freq/1e6:.2f} MHz")
    print(f"  Gain: {sdr.gain}")
    
    # Capture samples
    samples = sdr.read_samples(256*1024)
    sdr.close()
    
    print(f"Captured {len(samples)} samples")
    print(f"Sample range: {np.min(samples):.3f} to {np.max(samples):.3f}")
    
    # Simple plot
    plt.figure(figsize=(10, 4))
    plt.plot(np.real(samples[:1000]))
    plt.title("RTL-SDR Sample Data (Real Part)")
    plt.xlabel("Sample")
    plt.ylabel("Amplitude")
    plt.savefig("~/sdr-projects/captures/test_capture.png")
    print("Saved plot to ~/sdr-projects/captures/test_capture.png")
    
except ImportError:
    print("pyrtlsdr not installed. Install with: pip3 install pyrtlsdr")
except Exception as e:
    print(f"Error: {e}")
    print("Make sure RTL-SDR device is connected")
EOF

    chmod +x ~/sdr-projects/scripts/test_rtlsdr.py
    
    echo "[+] Example scripts created"
}

# Function to show completion message
show_completion() {
    echo
    echo "=================================================="
    echo "   SDR Communications Kit Setup Complete!"
    echo "=================================================="
    echo
    echo "Installed tools:"
    echo "  • GNU Radio & GRC (GNU Radio Companion)"
    echo "  • GQRX SDR spectrum analyzer"
    echo "  • RTL-SDR utilities (rtl_test, rtl_fm, etc.)"
    echo "  • HackRF utilities"
    echo "  • Python SDR libraries (pyrtlsdr)"
    echo
    echo "Example projects created at: ~/sdr-projects/"
    echo
    echo "Quick start commands:"
    echo "  gqrx                                    # Launch GQRX"
    echo "  gnuradio-companion                      # Launch GNU Radio Companion"
    echo "  rtl_test                                # Test RTL-SDR connectivity"
    echo "  ~/sdr-projects/scripts/test_rtlsdr.py   # Test Python RTL-SDR"
    echo "  ~/sdr-projects/scripts/simple_fm_receiver.py 101.5  # FM radio"
    echo
    echo "Supported devices:"
    echo "  • RTL-SDR dongles (R820T/R820T2/E4000)"
    echo "  • HackRF One"
    echo "  • AirSpy devices"
    echo
    echo "⚠️  Note: You may need to log out/in for group changes to take effect"
    echo
}

# Main execution
main() {
    if ! check_internet; then
        exit 1
    fi
    
    install_system_deps
    install_sdr_tools
    install_python_sdr
    setup_udev_rules
    create_examples
    show_completion
}

# Run main function
main "$@"
