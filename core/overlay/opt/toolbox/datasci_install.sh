#!/usr/bin/env bash
# Data Science Workbench (Ubuntu LTS) installer

set -e

echo "=================================================="
echo "   USBFREEDOM Data Science Workbench Setup"
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
    sudo apt-get install -y wget curl git build-essential >/dev/null 2>&1
    echo "[+] System dependencies installed"
}

# Function to install Miniconda
install_miniconda() {
    echo "[+] Installing Miniconda..."
    
    if [ -d "$HOME/miniconda3" ]; then
        echo "  Miniconda already installed, skipping..."
        return 0
    fi
    
    cd /tmp
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    bash Miniconda3-latest-Linux-x86_64.sh -b -p "$HOME/miniconda3"
    
    # Initialize conda
    "$HOME/miniconda3/bin/conda" init bash
    source "$HOME/.bashrc"
    
    echo "[+] Miniconda installed successfully"
}

# Function to create data science environment
create_datascience_env() {
    echo "[+] Creating data science environment..."
    
    # Use full path to conda to ensure it's found
    CONDA_PATH="$HOME/miniconda3/bin/conda"
    
    # Create environment with essential packages
    "$CONDA_PATH" create -n datascience python=3.11 -y >/dev/null 2>&1
    
    # Activate environment and install packages
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
    conda activate datascience
    
    echo "  Installing core data science packages..."
    conda install -y numpy pandas matplotlib seaborn scikit-learn >/dev/null 2>&1
    
    echo "  Installing Jupyter and extensions..."
    conda install -y jupyterlab jupyter >/dev/null 2>&1
    
    echo "  Installing additional tools..."
    pip install duckdb plotly streamlit >/dev/null 2>&1
    
    echo "[+] Data science environment created"
}

# Function to setup sample notebooks
setup_notebooks() {
    echo "[+] Setting up sample notebooks and datasets..."
    
    mkdir -p ~/datascience/{notebooks,datasets,projects}
    
    # Create a sample notebook
    cat > ~/datascience/notebooks/welcome.ipynb << 'EOF'
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# Welcome to USBFREEDOM Data Science Workbench\n",
    "\n",
    "This environment includes:\n",
    "- Python 3.11\n",
    "- Pandas, NumPy, Matplotlib, Seaborn\n",
    "- Scikit-learn for machine learning\n",
    "- JupyterLab for interactive development\n",
    "- DuckDB for analytics\n",
    "- Plotly for interactive visualizations\n",
    "\n",
    "## Quick Start\n",
    "\n",
    "Run the cell below to test your environment:"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "import pandas as pd\n",
    "import numpy as np\n",
    "import matplotlib.pyplot as plt\n",
    "import seaborn as sns\n",
    "\n",
    "# Create sample data\n",
    "data = pd.DataFrame({\n",
    "    'x': np.random.randn(100),\n",
    "    'y': np.random.randn(100)\n",
    "})\n",
    "\n",
    "# Create a simple plot\n",
    "plt.figure(figsize=(8, 6))\n",
    "sns.scatterplot(data=data, x='x', y='y')\n",
    "plt.title('Welcome to Data Science!')\n",
    "plt.show()\n",
    "\n",
    "print('Environment is working correctly!')"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
EOF
    
    echo "[+] Sample notebooks created"
}

# Function to show completion message
show_completion() {
    echo
    echo "=================================================="
    echo "   Data Science Workbench Setup Complete!"
    echo "=================================================="
    echo
    echo "To get started:"
    echo "  1. Activate the environment: conda activate datascience"
    echo "  2. Launch JupyterLab: jupyter lab ~/datascience/notebooks"
    echo "  3. Open the welcome.ipynb notebook to test your setup"
    echo
    echo "Installed packages:"
    echo "  • Core: numpy, pandas, matplotlib, seaborn"
    echo "  • ML: scikit-learn"
    echo "  • Interactive: jupyterlab, plotly"
    echo "  • Analytics: duckdb"
    echo "  • Web apps: streamlit"
    echo
    echo "Happy data science!"
    echo
}

# Function to launch environment
launch_environment() {
    echo "Would you like to launch JupyterLab now? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Launching JupyterLab..."
        source "$HOME/miniconda3/etc/profile.d/conda.sh"
        conda activate datascience
        cd ~/datascience/notebooks
        jupyter lab --ip=0.0.0.0 --no-browser
    fi
}

# Main execution
main() {
    if ! check_internet; then
        exit 1
    fi
    
    install_system_deps
    install_miniconda
    create_datascience_env
    setup_notebooks
    show_completion
    launch_environment
}

# Run main function
main "$@"
