# Linux Load Test and System Observations

## Summary of Load Test Experience and Production Recommendations

When I ran the stress tests, the system took a heavy hit. I was keeping an eye on CPU and memory metrics live using `top` while checking the generated monitor logs in `/var/log`. The RAM got eaten up quickly—almost like a memory leak—and the server became really slow and unresponsive even after the test finished. Checking `dmesg`, I saw kernel OOM (Out-Of-Memory) killer errors triggered because the memory limit was pushed to the edge. Another issue I ran into was getting locked out of SSH after setting up the new port; I made a mistake during the SSH config setup and got blocked, so I had to wipe the setup and start again from scratch to get access back.

If this were a real production server, I would handle things much more carefully:
1. **Resource Limits via cgroups/systemd**: I would set strict memory and CPU limits using systemd cgroups (`MemoryMax`, `CPUQuota`) on background services so a single runaway process can't drain all the server's RAM or trigger host-wide OOM kills.
2. **Safe SSH Deployment**: Instead of applying new SSH port rules and restarting the daemon immediately, I would keep the current active SSH session open in one terminal while testing the new port connection in another window, or use a cloud serial console / AWS SSM to prevent accidental lockouts.
3. **Staging Environment Isolation**: I would never run heavy stress testing tools like `stress-ng` directly on a live production server; all load and memory leak tests would be strictly performed in a staging environment.
4. **Centralized Monitoring and Alerting**: Instead of relying only on local cron scripts logging to disk, I would set up production monitoring tools like Prometheus, Grafana, or Datadog with automated alerts for memory leaks, CPU spikes, and OOM events.
5. **Kernel OOM Tuning**: I would fine-tune `oom_score_adj` for core system daemons to ensure the kernel kills non-critical background jobs first if memory becomes exhausted.

---

## 1. Service User and System Isolation
* **User Created**: `bgdsvc_taufiq789`
* **Shell**: `/usr/sbin/nologin` (Prevents interactive login sessions for daemon and service security).
* **Home Directory**: `/home/bgdsvc_taufiq789`

---

## 2. In-Memory Filesystem (tmpfs) Observation
* **Mount Directory**: `/mnt/bgdsvc_taufiq789_tmp`
* **Allocated Size**: `256MB`
* **Observation**:
  * Writing files via `dd` fills RAM-backed storage without causing disk I/O bottlenecks.
  * Data stored in `tmpfs` is volatile and automatically cleared upon unmounting or system reboot.
  * Storage space is dynamically managed up to the `256M` limit.

---

## 3. Swap Space and Memory Behavior Under Load
* **Swap Allocation**: `2GB` (`/swapfile`) with `vm.swappiness=10`.
* **Baseline Memory**: High available RAM, 0% Swap usage.
* **Stress Test Behavior (`stress-ng --vm 1 --vm-bytes 200M`)**:
  * Memory consumption increased rapidly during stress test execution.
  * `vm.swappiness=10` ensured swap memory was utilized only when RAM saturation approached threshold limits, preventing aggressive disk thrashing.
  * Kernel Out-Of-Memory (OOM) killer events were observed in `dmesg` when combined stress tests exceeded allocated memory boundaries.

---

## 4. SSH Hardening Verification
* **Port Changed**: `22` -> `2222`
* **Authentication**: Key-based authentication enforcing ED25519 (`~/.ssh/bgdsvc_taufiq789_key`).
* **Disallowed**: Password authentication (`PasswordAuthentication no`) and Direct root login (`PermitRootLogin no`).
* **Result**: Successfully connected via `ssh -i ~/.ssh/bgdsvc_taufiq789_key -p 2222 bgdsvc_taufiq789@localhost`.

---

## 5. Automation and Log Rotation
* **Cron Jobs**:
  * Health check monitor (`bgdsvc_taufiq789_monitor.sh`) runs every 5 minutes (`*/5 * * * *`).
  * Scratch file cleanup (`bgdsvc_taufiq789_cleanup_old_files.sh`) runs daily at 02:00 AM (`0 2 * * *`).
* **Logrotate Policy**: Rotates `/var/log/bgdsvc_taufiq789/*.log` daily or at `10M` file size, retaining 5 compressed backup files.
