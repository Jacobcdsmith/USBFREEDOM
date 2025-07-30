#!/usr/bin/env bash
# Mobile Development SDK installer

set -e

echo "=================================================="
echo "   USBFREEDOM Mobile Development SDK Setup"
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

# Function to detect package manager
detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    else
        echo "unknown"
    fi
}

# Function to install system dependencies
install_system_deps() {
    echo "[+] Installing system dependencies..."
    
    local pm=$(detect_package_manager)
    
    case $pm in
        "apt")
            sudo apt-get update >/dev/null 2>&1
            sudo apt-get install -y wget curl git unzip openjdk-17-jdk >/dev/null 2>&1
            ;;
        "pacman")
            sudo pacman -Sy --noconfirm wget curl git unzip jdk17-openjdk >/dev/null 2>&1
            ;;
        "dnf")
            sudo dnf install -y wget curl git unzip java-17-openjdk-devel >/dev/null 2>&1
            ;;
        *)
            echo "[-] Unsupported package manager. Please install manually:"
            echo "    - wget, curl, git, unzip"
            echo "    - Java 17 JDK"
            exit 1
            ;;
    esac
    
    echo "[+] System dependencies installed"
}

# Function to install Android SDK
install_android_sdk() {
    echo "[+] Installing Android SDK..."
    
    mkdir -p ~/development/android
    cd ~/development/android
    
    # Download Android command line tools
    if [ ! -f "commandlinetools-linux-latest.zip" ]; then
        echo "  Downloading Android command line tools..."
        wget -q https://dl.google.com/android/repository/commandlinetools-linux-latest.zip
    fi
    
    if [ ! -d "cmdline-tools" ]; then
        unzip -q commandlinetools-linux-latest.zip
        mkdir -p cmdline-tools/latest
        mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true
    fi
    
    # Set up environment
    export ANDROID_HOME=~/development/android
    export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
    
    # Accept licenses and install platform tools
    echo "  Installing SDK components..."
    yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null 2>&1 || true
    $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" >/dev/null 2>&1
    
    echo "[+] Android SDK installed"
}

# Function to install Flutter
install_flutter() {
    echo "[+] Installing Flutter SDK..."
    
    mkdir -p ~/development
    cd ~/development
    
    if [ ! -d "flutter" ]; then
        echo "  Downloading Flutter..."
        git clone https://github.com/flutter/flutter.git -b stable >/dev/null 2>&1
    else
        echo "  Updating existing Flutter installation..."
        cd flutter
        git pull >/dev/null 2>&1
        cd ..
    fi
    
    # Add to PATH
    export PATH="$PATH:~/development/flutter/bin"
    
    echo "[+] Flutter SDK installed"
}

# Function to setup development environment
setup_dev_environment() {
    echo "[+] Setting up development environment..."
    
    # Create environment setup script
    cat > ~/development/setup-env.sh << 'EOF'
#!/bin/bash
# Mobile development environment setup

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=~/development/android
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
export PATH="$PATH:~/development/flutter/bin"

echo "Mobile development environment configured"
echo "Android Home: $ANDROID_HOME"
echo "Flutter: $(which flutter 2>/dev/null || echo 'Not in PATH yet')"
echo "Java: $JAVA_HOME"
EOF
    
    chmod +x ~/development/setup-env.sh
    
    # Add to .bashrc if not already there
    if ! grep -q "development/setup-env.sh" ~/.bashrc; then
        echo "source ~/development/setup-env.sh" >> ~/.bashrc
    fi
    
    echo "[+] Development environment configured"
}

# Function to setup Android device rules
setup_android_rules() {
    echo "[+] Setting up Android device udev rules..."
    
    sudo tee /etc/udev/rules.d/51-android.rules > /dev/null << 'EOF'
# Android device rules for development
SUBSYSTEM=="usb", ATTR{idVendor}=="0bb4", MODE="0666", GROUP="plugdev" # HTC
SUBSYSTEM=="usb", ATTR{idVendor}=="0502", MODE="0666", GROUP="plugdev" # Acer
SUBSYSTEM=="usb", ATTR{idVendor}=="0b05", MODE="0666", GROUP="plugdev" # Asus
SUBSYSTEM=="usb", ATTR{idVendor}=="413c", MODE="0666", GROUP="plugdev" # Dell
SUBSYSTEM=="usb", ATTR{idVendor}=="0489", MODE="0666", GROUP="plugdev" # Foxconn
SUBSYSTEM=="usb", ATTR{idVendor}=="04c5", MODE="0666", GROUP="plugdev" # Fujitsu
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev" # Google
SUBSYSTEM=="usb", ATTR{idVendor}=="109b", MODE="0666", GROUP="plugdev" # Hisense
SUBSYSTEM=="usb", ATTR{idVendor}=="0bb4", MODE="0666", GROUP="plugdev" # HTC
SUBSYSTEM=="usb", ATTR{idVendor}=="12d1", MODE="0666", GROUP="plugdev" # Huawei
SUBSYSTEM=="usb", ATTR{idVendor}=="24e3", MODE="0666", GROUP="plugdev" # K-Touch
SUBSYSTEM=="usb", ATTR{idVendor}=="2116", MODE="0666", GROUP="plugdev" # KT Tech
SUBSYSTEM=="usb", ATTR{idVendor}=="0482", MODE="0666", GROUP="plugdev" # Kyocera
SUBSYSTEM=="usb", ATTR{idVendor}=="17ef", MODE="0666", GROUP="plugdev" # Lenovo
SUBSYSTEM=="usb", ATTR{idVendor}=="1004", MODE="0666", GROUP="plugdev" # LG
SUBSYSTEM=="usb", ATTR{idVendor}=="22b8", MODE="0666", GROUP="plugdev" # Motorola
SUBSYSTEM=="usb", ATTR{idVendor}=="0409", MODE="0666", GROUP="plugdev" # NEC
SUBSYSTEM=="usb", ATTR{idVendor}=="2080", MODE="0666", GROUP="plugdev" # Nook
SUBSYSTEM=="usb", ATTR{idVendor}=="0955", MODE="0666", GROUP="plugdev" # Nvidia
SUBSYSTEM=="usb", ATTR{idVendor}=="2257", MODE="0666", GROUP="plugdev" # OTGV
SUBSYSTEM=="usb", ATTR{idVendor}=="10a9", MODE="0666", GROUP="plugdev" # Pantech
SUBSYSTEM=="usb", ATTR{idVendor}=="1d4d", MODE="0666", GROUP="plugdev" # Pegatron
SUBSYSTEM=="usb", ATTR{idVendor}=="0471", MODE="0666", GROUP="plugdev" # Philips
SUBSYSTEM=="usb", ATTR{idVendor}=="04da", MODE="0666", GROUP="plugdev" # PMC-Sierra
SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", MODE="0666", GROUP="plugdev" # Qualcomm
SUBSYSTEM=="usb", ATTR{idVendor}=="1f53", MODE="0666", GROUP="plugdev" # SK Telesys
SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666", GROUP="plugdev" # Samsung
SUBSYSTEM=="usb", ATTR{idVendor}=="04dd", MODE="0666", GROUP="plugdev" # Sharp
SUBSYSTEM=="usb", ATTR{idVendor}=="054c", MODE="0666", GROUP="plugdev" # Sony
SUBSYSTEM=="usb", ATTR{idVendor}=="0fce", MODE="0666", GROUP="plugdev" # Sony Ericsson
SUBSYSTEM=="usb", ATTR{idVendor}=="2340", MODE="0666", GROUP="plugdev" # Teleepoch
SUBSYSTEM=="usb", ATTR{idVendor}=="0930", MODE="0666", GROUP="plugdev" # Toshiba
SUBSYSTEM=="usb", ATTR{idVendor}=="19d2", MODE="0666", GROUP="plugdev" # ZTE
EOF

    sudo chmod a+r /etc/udev/rules.d/51-android.rules
    sudo udevadm control --reload-rules
    sudo usermod -a -G plugdev $USER
    
    echo "[+] Android device rules configured"
}

# Function to create sample project
create_sample_project() {
    echo "[+] Creating sample Flutter project..."
    
    mkdir -p ~/development/projects
    cd ~/development/projects
    
    # Source environment
    source ~/development/setup-env.sh
    
    # Create sample app if it doesn't exist
    if [ ! -d "hello_mobile" ]; then
        flutter create hello_mobile >/dev/null 2>&1
        
        # Create a simple customization
        cat > hello_mobile/lib/main.dart << 'EOF'
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USBFREEDOM Mobile Dev',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'USBFREEDOM Mobile Development'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Welcome to USBFREEDOM Mobile Development!',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              'You have pressed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
EOF
    fi
    
    echo "[+] Sample project created"
}

# Function to show completion message
show_completion() {
    echo
    echo "=================================================="
    echo "   Mobile Development SDK Setup Complete!"
    echo "=================================================="
    echo
    echo "Installed components:"
    echo "  • Java 17 JDK"
    echo "  • Android SDK (API 34, build-tools 34.0.0)"
    echo "  • Flutter SDK (stable channel)"
    echo "  • Android device udev rules"
    echo
    echo "Sample project: ~/development/projects/hello_mobile"
    echo
    echo "To get started:"
    echo "  1. Restart your terminal or run: source ~/.bashrc"
    echo "  2. Enable Developer Options & USB Debugging on your Android device"
    echo "  3. Connect your device and run: flutter devices"
    echo "  4. Navigate to sample project: cd ~/development/projects/hello_mobile"
    echo "  5. Run the app: flutter run"
    echo
    echo "Useful commands:"
    echo "  flutter doctor          # Check setup"
    echo "  flutter devices         # List connected devices"
    echo "  flutter create myapp    # Create new project"
    echo "  adb devices            # List Android devices"
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
    install_android_sdk
    install_flutter
    setup_dev_environment
    setup_android_rules
    create_sample_project
    show_completion
}

# Run main function
main "$@"
