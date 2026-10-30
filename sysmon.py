#!/usr/bin/env python3
import json, os, subprocess, re, time
from datetime import date
from collections import defaultdict

def fmt_b(b):
    if b >= 1024 * 1024 * 1024:
        return f"{b / (1024**3):.1f} GB"
    if b >= 1024 * 1024:
        return f"{b / (1024**2):.0f} MB"
    if b >= 1024:
        return f"{b / 1024:.0f} KB"
    return f"{b} B"

def pad(s, width):
    return s + " " * max(0, width - len(s))

def rpad(s, width):
    return " " * max(0, width - len(s)) + s

def get_icon(name):
    low = name.lower()
    if any(x in low for x in ["brave", "chrome", "chromium", "firefox", "zen", "browser"]):
        return ""
    if any(x in low for x in ["telegram", "ayugram"]):
        return ""
    if any(x in low for x in ["code", "codium", "studio", "android"]):
        return "󰅩"
    if any(x in low for x in ["agy", "antigravity", "gemini"]):
        return "󰚩"
    if any(x in low for x in ["discord", "vesktop"]):
        return "󰙯"
    if any(x in low for x in ["spotify"]):
        return ""
    if any(x in low for x in ["kitty", "foot", "alacritty", "ghostty", "bash", "zsh", "fish"]):
        return ""
    if any(x in low for x in ["hypr", "quick", "waybar"]):
        return ""
    if any(x in low for x in ["python"]):
        return ""
    if any(x in low for x in ["btop", "htop"]):
        return "󰓅"
    return "󰣖"

# --- 1. CPU SYSTEM & LIVE PROCESS TICK CALCULATION ---
shm_proc_file = "/dev/shm/sysmon_proc.json"
now_time = time.time()

with open("/proc/stat", "r") as f:
    stat_lines = f.readlines()

cpu_parts = stat_lines[0].split()
idle = int(cpu_parts[4]) + int(cpu_parts[5])
sys_total = sum(int(x) for x in cpu_parts[1:])

boot_time = 0
for line in stat_lines:
    if line.startswith("btime "):
        boot_time = int(line.split()[1])
        break

# Read current process ticks & memory from /proc directly
curr_procs = {}
mem_by_comm = defaultdict(int)

for pid in os.listdir("/proc"):
    if pid.isdigit():
        try:
            # Read stat for cpu (utime + stime)
            with open(f"/proc/{pid}/stat", "r") as f:
                c = f.read()
            l = c.find("(")
            r = c.rfind(")")
            comm = c[l+1:r]
            flds = c[r+2:].split()
            ticks = int(flds[11]) + int(flds[12])
            curr_procs[pid] = (comm, ticks)

            # Read statm for memory (resident pages * 4096)
            with open(f"/proc/{pid}/statm", "r") as f:
                res_pages = int(f.read().split()[1])
                mem_by_comm[comm] += res_pages * 4096
        except Exception:
            pass

# Compute live CPU % between successive samples
live_cpu_by_comm = defaultdict(float)
if os.path.exists(shm_proc_file):
    try:
        with open(shm_proc_file, "r") as f:
            prev_data = json.load(f)
            prev_sys = prev_data.get("sys_total", 0)
            prev_procs = prev_data.get("procs", {})
            sys_delta = sys_total - prev_sys

            if sys_delta > 0:
                for pid, (comm, ticks) in curr_procs.items():
                    if pid in prev_procs:
                        pticks = prev_procs[pid][1]
                        delta = ticks - pticks
                        if delta > 0:
                            pct = 100.0 * (delta / sys_delta)
                            live_cpu_by_comm[comm] += pct
    except Exception:
        pass

# Save current proc ticks for next run
try:
    with open(shm_proc_file, "w") as f:
        json.dump({
            "sys_total": sys_total,
            "time": now_time,
            "procs": curr_procs
        }, f)
except Exception:
    pass

# Format Top CPU lines
top_cpu_lines = []
active_cpu = sorted(live_cpu_by_comm.items(), key=lambda x: x[1], reverse=True)
for comm, pct in active_cpu[:5]:
    if pct >= 0.1:
        top_cpu_lines.append(f"{get_icon(comm)} {pad(comm[:15], 15)} {rpad(f'{pct:.1f}%', 7)}")

if not top_cpu_lines:
    top_cpu_lines.append("󰌪 System is idle (<0.1%)")

# --- 2. MEMORY & SWAP ---
mem_info = {}
try:
    with open("/proc/meminfo", "r") as f:
        for line in f:
            parts = line.split(":")
            if len(parts) == 2:
                mem_info[parts[0].strip()] = int(parts[1].split()[0])
except Exception:
    pass

mem_total_kb = mem_info.get("MemTotal", 1)
mem_avail_kb = mem_info.get("MemAvailable", 0)
mem_used_kb = mem_total_kb - mem_avail_kb
mem_pct = round(100 * mem_used_kb / mem_total_kb)

swap_total_kb = mem_info.get("SwapTotal", 0)
swap_free_kb = mem_info.get("SwapFree", 0)
swap_used_kb = swap_total_kb - swap_free_kb
swap_pct = round(100 * swap_used_kb / swap_total_kb) if swap_total_kb > 0 else 0

load_str = ""
try:
    with open("/proc/loadavg", "r") as f:
        load_parts = f.read().split()[:3]
        load_str = f"{load_parts[0]}, {load_parts[1]}, {load_parts[2]}"
except Exception:
    pass

# Format Top Memory lines
top_mem_lines = []
for comm, b in sorted(mem_by_comm.items(), key=lambda x: x[1], reverse=True)[:5]:
    if b > 1024 * 1024:
        pct_mem = round(100.0 * (b / (mem_total_kb * 1024)))
        top_mem_lines.append(f"{get_icon(comm)} {pad(comm[:14], 14)} {rpad(fmt_b(b), 6)} ({pct_mem:>2}%)")

# --- 3. NETWORK INTERFACE BYTES ---
net_rx = 0
net_tx = 0
try:
    with open("/proc/net/dev", "r") as f:
        for line in f:
            if ":" in line:
                dev, rest = line.split(":", 1)
                dev = dev.strip()
                if dev != "lo" and not re.match(r"^(docker|veth|virbr|br-)", dev):
                    fields = rest.split()
                    net_rx += int(fields[0])
                    net_tx += int(fields[8])
except Exception:
    pass

# --- 4. PERSISTENT DAILY NETWORK & PER-APP TRAFFIC ---
state_dir = os.path.expanduser("~/.local/state/omarchy")
os.makedirs(state_dir, exist_ok=True)
net_file = os.path.join(state_dir, "sysmon_net.json")
shm_sock_file = "/dev/shm/sysmon_sockets.json"
today_str = str(date.today())

accum_rx = 0
accum_tx = 0
apps_data = {}
stored_btime = boot_time

# Load persistent daily data
if os.path.exists(net_file):
    try:
        with open(net_file, "r") as f:
            sdata = json.load(f)
            if sdata.get("date") == today_str:
                accum_rx = sdata.get("accum_rx", 0)
                accum_tx = sdata.get("accum_tx", 0)
                stored_btime = sdata.get("btime", boot_time)
                apps_data = sdata.get("apps", {})
                old_last_rx = sdata.get("last_rx", net_rx)
                old_last_tx = sdata.get("last_tx", net_tx)

                # Check if reboot occurred today
                if boot_time != stored_btime:
                    accum_rx += old_last_rx
                    accum_tx += old_last_tx
                    stored_btime = boot_time
    except Exception:
        pass

# Read active sockets from ss and compute deltas
prev_socks = {}
if os.path.exists(shm_sock_file):
    try:
        with open(shm_sock_file, "r") as f:
            prev_socks = json.load(f)
    except Exception:
        pass

curr_socks = {}
try:
    ss_out = subprocess.check_output(["ss", "-tup", "-i"], text=True)
    cur_p = None
    cur_key = None
    for line in ss_out.splitlines():
        if re.search(r"\bESTAB\b", line):
            cur_p = "system"
            m = re.search(r"users:\(\(\"([^\"]+)\"", line)
            if m:
                cur_p = m.group(1)
            parts = line.split()
            if len(parts) >= 5:
                cur_key = f"{parts[4]}->{parts[5]}"
            else:
                cur_key = f"sock_{len(curr_socks)}"
        elif cur_key and ("bytes_sent:" in line or "bytes_received:" in line):
            m_sent = re.search(r"bytes_sent:(\d+)", line)
            m_recv = re.search(r"bytes_received:(\d+)", line)
            s_val = int(m_sent.group(1)) if m_sent else 0
            r_val = int(m_recv.group(1)) if m_recv else 0
            curr_socks[cur_key] = {"proc": cur_p, "tx": s_val, "rx": r_val}

            # Calculate delta for this socket
            if cur_key in prev_socks:
                p_entry = prev_socks[cur_key]
                d_tx = max(0, s_val - p_entry.get("tx", 0))
                d_rx = max(0, r_val - p_entry.get("rx", 0))
            else:
                # First time seeing this socket
                d_tx = s_val
                d_rx = r_val

            if d_tx > 0 or d_rx > 0:
                if cur_p not in apps_data:
                    apps_data[cur_p] = {"rx": 0, "tx": 0, "total": 0}
                apps_data[cur_p]["rx"] += d_rx
                apps_data[cur_p]["tx"] += d_tx
                apps_data[cur_p]["total"] += (d_rx + d_tx)
except Exception:
    pass

# Save active sockets in shm
try:
    with open(shm_sock_file, "w") as f:
        json.dump(curr_socks, f)
except Exception:
    pass

# Daily total bytes
daily_rx = accum_rx + net_rx
daily_tx = accum_tx + net_tx
daily_total = daily_rx + daily_tx

# Save persistent state atomically
try:
    tmp_file = net_file + ".tmp"
    with open(tmp_file, "w") as f:
        json.dump({
            "date": today_str,
            "btime": stored_btime,
            "accum_rx": accum_rx,
            "accum_tx": accum_tx,
            "last_rx": net_rx,
            "last_tx": net_tx,
            "apps": apps_data
        }, f, indent=2)
    os.replace(tmp_file, net_file)
except Exception:
    pass

# Format Top Network lines
top_net_lines = []
total_apps_bytes = 0
for pname, data in sorted(apps_data.items(), key=lambda x: x[1].get("total", 0), reverse=True):
    tot = data.get("total", 0)
    if tot > 1024:
        total_apps_bytes += tot
        top_net_lines.append(f"{get_icon(pname)} {pad(pname[:15], 15)} {rpad(fmt_b(tot), 8)}")
    if len(top_net_lines) >= 4:
        break

other_bytes = max(0, daily_total - total_apps_bytes)
if other_bytes > 1024 * 1024 and len(top_net_lines) < 5:
    top_net_lines.append(f"󰒋 {pad('other/system', 15)} {rpad(fmt_b(other_bytes), 8)}")

if not top_net_lines:
    top_net_lines.append("󰛳 No app traffic recorded yet")

res = {
    "rx": net_rx,
    "tx": net_tx,
    "idle": idle,
    "total": sys_total,
    "mem_used_kb": mem_used_kb,
    "mem_total_kb": mem_total_kb,
    "mem_pct": mem_pct,
    "swap_used_kb": swap_used_kb,
    "swap_total_kb": swap_total_kb,
    "swap_pct": swap_pct,
    "load": load_str,
    "daily_rx": daily_rx,
    "daily_tx": daily_tx,
    "daily_total_str": fmt_b(daily_total),
    "daily_rx_str": fmt_b(daily_rx),
    "daily_tx_str": fmt_b(daily_tx),
    "top_cpu_lines": top_cpu_lines,
    "top_mem_lines": top_mem_lines,
    "top_net_lines": top_net_lines
}

print(json.dumps(res))
