import subprocess
import logging
from pathlib import Path
from typing import List, Optional, Dict

logger = logging.getLogger(__name__)

def run_command(cmd: List[str], cwd: Optional[Path] = None, env: Optional[Dict[str, str]] = None, check: bool = True) -> subprocess.CompletedProcess:
    """Run a shell command."""
    logger.info(f"Running command: {' '.join(cmd)}")
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            env=env,
            check=check,
            capture_output=True,
            text=True
        )
        return result
    except subprocess.CalledProcessError as e:
        logger.error(f"Command failed: {e.stderr}")
        raise

def ensure_dir(path: Path):
    """Ensure a directory exists."""
    if not path.exists():
        path.mkdir(parents=True, exist_ok=True)

def get_project_root() -> Path:
    """Get the project root directory."""
    return Path(__file__).resolve().parent.parent
