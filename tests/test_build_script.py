import os
from pathlib import Path
import subprocess
import sys

SCRIPT_PATH = (Path(__file__).resolve().parent.parent / 'build.sh').as_posix()


def run_script(args, env=None, cwd=None):
    # Execute the script via bash to avoid relying on executable permissions
    return subprocess.run(['bash', SCRIPT_PATH, *args], capture_output=True, text=True, env=env, cwd=cwd)


def test_no_arguments():
    result = run_script([])
    assert result.returncode == 1
    assert 'Usage' in result.stdout or 'Usage' in result.stderr


def test_one_argument():
    result = run_script(['onlyone'])
    assert result.returncode == 1
    assert 'Usage' in result.stdout or 'Usage' in result.stderr


def test_two_arguments(tmp_path):
    # Create stubs for 7z and mkisofs so the script can run
    bin_dir = tmp_path / 'bin'
    bin_dir.mkdir()
    stub_7z = bin_dir / '7z'
    stub_mkisofs = bin_dir / 'mkisofs'

    stub_7z.write_text('\n'.join([
        '#!/usr/bin/env bash',
        'out=""',
        'for arg in "$@"; do',
        '  case "$arg" in',
        '    -o*) out="${arg#-o}" ;;',
        '  esac',
        'done',
        'mkdir -p "$out"',
    ]) + '\n')
    stub_mkisofs.write_text('#!/usr/bin/env bash\nwhile [ "$1" != "-o" ]; do shift; done; output=$2; shift 2; touch "$output"\n')
    stub_7z.chmod(0o755)
    stub_mkisofs.chmod(0o755)

    env = os.environ.copy()
    env['PATH'] = f"{bin_dir}:{env['PATH']}"

    iso = tmp_path / 'dummy.iso'
    iso.write_text('iso')
    output_img = tmp_path / 'out.img'

    # Create expected core/overlay path
    core_dir = tmp_path / 'core'
    core_dir.mkdir()
    overlay_link = core_dir / 'overlay'
    overlay_link.symlink_to(Path(__file__).resolve().parent.parent / 'core' / 'overlay')

    result = run_script([str(iso), str(output_img)], env=env, cwd=tmp_path)
    assert 'Usage' not in result.stdout + result.stderr
    assert output_img.exists()
