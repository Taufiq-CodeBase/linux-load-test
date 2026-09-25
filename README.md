# Linux Load Test, Monitoring and Security Hardening Lab

A Linux system administration suite designed for system resource stress testing, swap allocation, RAM-backed filesystem (tmpfs) management, automated logging and cron scheduling, and SSH security hardening.

---

## Repository Overview

This repository contains shell scripts and screenshot evidence for a Linux performance and security administration workflow:

1. User Account Provisioning: Creation of dedicated non-interactive system service users (`$SVC_NAME`).
2. In-Memory Storage (tmpfs): Dynamic creation and mounting of a RAM disk (`256M`) with proper access controls.
3. Swap Space Management: Allocation and tuning (`vm.swappiness=10`) of a persistent `2GB` swapfile.
4. Stress and Load Testing: CPU, Memory, and Disk load generation using `stress-ng` and `dd`, triggering Kernel OOM (Out-Of-Memory) observation routines.
5. Security Hardening: SSH server configuration on non-standard port `2222`, disabling root login and password authentication, enforced with ED25519 public key authentication.
6. Automation and Maintenance: Periodic system health metrics collection, tmpfs purge routines via `cron`, and log rotation via `logrotate`.
7. Environment Teardown: Reversible cleanup script that safely wipes users, mounts, processes, cron tasks, and logs.

---

## File and Folder Structure

```
Linux Load Test/
├── README.md                              # Main repository documentation
├── OBSERVATION.md                         # Detailed observations and metrics log
├── Scripts/                               # Shell scripts directory
│   ├── 01_create_user.sh                  # System user provisioning
│   ├── 02_setup_tmpfs.sh                  # tmpfs RAM disk mount script
│   ├── 03_stress_and_populate.sh          # Resource stress & data population tool
│   ├── 04_cleanup.sh                      # Teardown & system restoration script
│   ├── setup_swap.sh                      # 2GB Swap space configuration script
│   ├── setup_ssh.sh                       # SSH keypair generation & setup
│   ├── secure_ssh.sh                      # SSH server hardening (Port 2222, key-only)
│   ├── automate_cron_and_logrotate.sh     # Cron job & logrotate setup wrapper
│   ├── bgdsvc_taufiq789_monitor.sh       # Monitoring script (executed by cron)
│   └── bgdsvc_taufiq789_cleanup_old_files.sh # File cleanup script (executed by cron)
└── Screenshots/                           # Execution proof screenshots
    ├── 01_SVC_NAME.png                    # Environment variable configuration
    ├── 02_ID_CREATED.png                  # System user creation verification
    ├── 03_df_before.png                   # Disk space before stress test
    ├── 04_df_after.png                    # Disk space after filling tmpfs
    ├── 05_free -h_before.png              # System memory baseline
    ├── 06_free -h_during.png              # System memory under peak load
    ├── 07_free -h_after.png               # System memory post stress test
    ├── 08_dmesg oom.png                   # Kernel OOM killer log output (1)
    ├── 08_dmesg_oom_out_of_memory.png     # Kernel OOM killer log output (2)
    ├── 09_ssh_success.png                 # Initial SSH setup verification
    ├── 09_ssh_success_on_ 2222_port.png    # SSH access on hardened port 2222
    ├── 09_ssh_success_with_login_permission.png # Key-based SSH authentication
    ├── 10_crontab_list.png                # Active crontab schedule
    ├── 11_monitor_log.png                 # Automated monitoring log entries
    ├── 12_cleanup.png                     # Teardown script execution
    └── 13_cleanup_verify.png              # Post-teardown system state check
```

---

## Prerequisites and Environment Setup

### Required Packages
Ensure your Linux environment has the necessary utilities installed:

```bash
sudo apt update
sudo apt install -y stress-ng openssh-server logrotate cron
```

### Environment Variable Setup
Set the `$SVC_NAME` environment variable before executing scripts. This variable defines the service account name, mount path, and log directory:

```bash
export SVC_NAME="bgdsvc_taufiq789"
```

---

## Scripts Breakdown

### 1. `01_create_user.sh`
* **What is the need:** Isolates service processes and lab activities under a dedicated system user account rather than running tasks under root or standard administrative accounts.
* **How it works:** Reads the `$SVC_NAME` environment variable. Checks if the user already exists using `id`. If missing, creates a system user with a disabled login shell (`/usr/sbin/nologin`) and a home directory using `useradd -r -m -s /usr/sbin/nologin`. Finally, displays user account details using `id` and `getent`.
* **How to use:**
  ```bash
  export SVC_NAME="bgdsvc_taufiq789"
  ./Scripts/01_create_user.sh
  ```

---

### 2. `02_setup_tmpfs.sh`
* **What is the need:** Provides ultra-fast RAM-backed temporary storage (`tmpfs`) to conduct high-speed file operations and disk stress tests without causing physical disk wear or disk I/O bottlenecks.
* **How it works:** Verifies `$SVC_NAME`. Creates the directory `/mnt/${SVC_NAME}_tmp` if it does not exist. Checks if the directory is already mounted using `mountpoint`. If unmounted, mounts a 256MB `tmpfs` partition to `/mnt/${SVC_NAME}_tmp` and changes directory ownership to `$SVC_NAME`. Verifies mount status using `df -h`.
* **How to use:**
  ```bash
  ./Scripts/02_setup_tmpfs.sh
  ```

---

### 3. `setup_swap.sh`
* **What is the need:** Prevents system crashes and unexpected process terminations when physical RAM becomes fully saturated during heavy memory load testing.
* **How it works:** Checks for root privileges (`$EUID`). Allocates a 2GB file at `/swapfile` using `fallocate` (or `dd` as fallback). Restricts file permissions to root-only (`chmod 600`). Formats the file as swap space with `mkswap` and activates it using `swapon`. Appends an entry to `/etc/fstab` for reboot persistence, and tunes `vm.swappiness=10` in `/etc/sysctl.conf` so the system swaps only when RAM usage is high.
* **How to use:**
  ```bash
  sudo ./Scripts/setup_swap.sh
  ```

---

### 4. `03_stress_and_populate.sh`
* **What is the need:** Generates controlled synthetic resource stress (CPU, Memory, and Disk load) to evaluate system performance under pressure and observe kernel behavior such as Out-Of-Memory (OOM) triggers.
* **How it works:** Accepts command-line flags (`--cpu`, `--mem`, `--disk`, `--all`).
  * `stress_disk`: Writes twenty 10MB test files into `/mnt/${SVC_NAME}_tmp` using `dd`.
  * `stress_cpu`: Runs 2 CPU stress workers for 30 seconds using `stress-ng`.
  * `stress_mem`: Allocates 200MB of virtual memory stress for 30 seconds using `stress-ng`.
  * `--all`: Executes disk, CPU, and memory stress functions concurrently in the background and waits for all processes to complete.
* **How to use:**
  ```bash
  # Run all stress tests concurrently
  ./Scripts/03_stress_and_populate.sh --all

  # Run individual stress tests
  ./Scripts/03_stress_and_populate.sh --cpu
  ./Scripts/03_stress_and_populate.sh --mem
  ./Scripts/03_stress_and_populate.sh --disk
  ```

---

### 5. `setup_ssh.sh`
* **What is the need:** Configures secure, passwordless SSH access for the service user using modern ED25519 keypair authentication.
* **How it works:** Generates an ED25519 key pair at `~/.ssh/${SVC_NAME}_key` if not already present. Creates `/home/${SVC_NAME}/.ssh/` directory and copies the public key into `authorized_keys`. Sets restrictive permissions (`700` for directory, `600` for authorized_keys) owned by `$SVC_NAME`. Ensures OpenSSH server service is installed and running.
* **How to use:**
  ```bash
  ./Scripts/setup_ssh.sh
  ```

---

### 6. `secure_ssh.sh`
* **What is the need:** Hardens the SSH daemon against automated brute-force attacks by disabling password authentication, disabling root login, changing the default port, and restricting allowed SSH users.
* **How it works:** Creates a timestamped backup of `/etc/ssh/sshd_config`. Replaces standard SSH settings to set `Port 2222`, `PermitRootLogin no`, `PasswordAuthentication no`, and `AllowUsers ubuntu $SVC_NAME`. Tests configuration syntax using `sshd -t`. If valid, restarts the SSH daemon (`systemctl restart ssh`). If invalid, automatically restores the backup file.
* **How to use:**
  ```bash
  sudo ./Scripts/secure_ssh.sh
  ```
  **Connecting via hardened SSH:**
  ```bash
  ssh -i ~/.ssh/bgdsvc_taufiq789_key -p 2222 bgdsvc_taufiq789@localhost
  ```

---

### 7. `automate_cron_and_logrotate.sh`
* **What is the need:** Automates background resource monitoring, temporary storage maintenance, and log rotation to prevent unmanaged log accumulation or disk exhaustion.
* **How it works:** Creates log directory `/var/log/${SVC_NAME}`. Dynamically generates two worker scripts:
  * `/usr/local/bin/${SVC_NAME}_monitor.sh`
  * `/usr/local/bin/${SVC_NAME}_cleanup_old_files.sh`
  
  Installs two cron jobs into `$SVC_NAME`'s crontab (monitor runs every 5 minutes; cleanup runs daily at 2:00 AM). Deploys a logrotate rule under `/etc/logrotate.d/${SVC_NAME}` configured for daily rotation, 10MB size limit, and 5 retention cycles. Validates logrotate using `logrotate -f`.
* **How to use:**
  ```bash
  sudo ./Scripts/automate_cron_and_logrotate.sh
  ```

---

### 8. `bgdsvc_taufiq789_monitor.sh`
* **What is the need:** Collects periodic system performance snapshots (memory, disk, processes) into a structured log file.
* **How it works:** Executed automatically by cron. Appends current timestamp, `free -h` (memory/swap status), `df -h` (tmpfs partition usage), and `ps -u` (active user processes) to `/var/log/bgdsvc_taufiq789/monitor.log`.
* **How to use:**
  Can be run manually or executed by cron every 5 minutes:
  ```bash
  /usr/local/bin/bgdsvc_taufiq789_monitor.sh
  ```

---

### 9. `bgdsvc_taufiq789_cleanup_old_files.sh`
* **What is the need:** Automatically purges old temporary files from the RAM disk to avoid running out of memory storage over time.
* **How it works:** Executed automatically by cron. Searches `/mnt/bgdsvc_taufiq789_tmp` for files modified more than 1 day ago (`find -mtime +1 -delete`) and logs the cleanup activity to `/var/log/bgdsvc_taufiq789/monitor.log`.
* **How to use:**
  Can be run manually or executed by cron daily at 2:00 AM:
  ```bash
  /usr/local/bin/bgdsvc_taufiq789_cleanup_old_files.sh
  ```

---

### 10. `04_cleanup.sh`
* **What is the need:** Restores the system back to its initial state by cleanly removing all lab resources, user accounts, mounts, cron schedules, and temporary configurations.
* **How it works:** Terminates all processes owned by `$SVC_NAME` using `pkill -u`. Clears user crontab tasks. Deletes script files from `/usr/local/bin/` and logrotate config from `/etc/logrotate.d/`. Unmounts and removes `/mnt/${SVC_NAME}_tmp`. Removes log directory `/var/log/${SVC_NAME}`. Deletes the service user and home directory using `userdel -r`. Performs post-teardown verification checks (`id`, `mount`, `ps`).
* **How to use:**
  ```bash
  sudo ./Scripts/04_cleanup.sh
  ```

---

## Screenshot Evidence Reference

The following table maps each screenshot in `Screenshots/` to its corresponding lab execution stage:

| Screenshot | Description and Demonstrated Stage |
| :--- | :--- |
| `01_SVC_NAME.png` | Setting and validating the `$SVC_NAME` environment variable. |
| `02_ID_CREATED.png` | Verifying created system user using `id` and `getent passwd`. |
| `03_df_before.png` | Disk space baseline (`df -h`) before writing files to `tmpfs`. |
| `04_df_after.png` | Disk space status (`df -h`) after populating `/mnt/${SVC_NAME}_tmp` with test data. |
| `05_free -h_before.png` | System baseline RAM and Swap usage (`free -h`) before stress testing. |
| `06_free -h_during.png` | Peak RAM and Swap utilization during concurrent `stress-ng` execution. |
| `07_free -h_after.png` | Memory reclamation status after stress tests finish. |
| `08_dmesg oom.png` | Initial Kernel message log (`dmesg`) showing Out-Of-Memory events. |
| `08_dmesg_oom_out_of_memory.png` | Detailed Kernel OOM killer invocation logs under high memory pressure. |
| `09_ssh_success.png` | Initial SSH connection setup verification. |
| `09_ssh_success_on_ 2222_port.png` | Verified SSH key-based login through hardened port `2222`. |
| `09_ssh_success_with_login_permission.png` | SSH access confirmation for restricted user account. |
| `10_crontab_list.png` | Crontab output (`crontab -l`) confirming active monitor and cleanup schedules. |
| `11_monitor_log.png` | Sample entries from `/var/log/${SVC_NAME}/monitor.log`. |
| `12_cleanup.png` | Execution output of `04_cleanup.sh` performing system teardown. |
| `13_cleanup_verify.png` | Post-cleanup verification commands showing full removal of user, mount, and processes. |

---

## Step-by-Step Execution Sequence

Follow this sequence to run the entire lab from setup to teardown:

```bash
# Step 1: Set Environment Variable
export SVC_NAME="bgdsvc_taufiq789"

# Step 2: Provision Service User
./Scripts/01_create_user.sh

# Step 3: Setup tmpfs RAM Disk
./Scripts/02_setup_tmpfs.sh

# Step 4: Setup and Enable Swap Space
sudo ./Scripts/setup_swap.sh

# Step 5: Execute Stress and Load Tests
./Scripts/03_stress_and_populate.sh --all

# Step 6: Configure and Harden SSH
./Scripts/setup_ssh.sh
sudo ./Scripts/secure_ssh.sh

# Step 7: Deploy Cron Automation and Logrotate Rules
sudo ./Scripts/automate_cron_and_logrotate.sh

# Step 8: Perform System Cleanup and Verification
sudo ./Scripts/04_cleanup.sh
```
