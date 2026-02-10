import subprocess
import os


def run_cmd(command):
    """
    Takes a string like 'sudo zypper ref' and runs it
    """
    print(f"Running: {command}")
    subprocess.run(command, shell=True, check=True)


run_cmd("sudo zypper up")

home_dir = os.environ["HOME"]
source_path = (
    f"{home_dir}/Git/configs/linux-system/tumbleweed/preconfig/99-custom-env.sh"
)
