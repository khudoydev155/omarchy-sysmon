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

# 1. CPU & MEM from /proc
idle = 0
total = 0
boot_time = 0
try:
    with open("/proc/stat", "r") as f:
        for line in f:
            if line.startswith("cpu "):
                parts = line.split()
                idle = int(parts[4]) + int(parts[5])
                total = sum(int(x) for x in parts[1:])
            elif line.startswith("btime "):
                boot_time = int(line.split()[1])
except Exception:
    pass

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

# 2. Net bytes from /proc/net/dev
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

# 3. Daily net tracking in ~/.cache/omarchy/sysmon_net.json
cache_dir = os.path.expanduser("~/.cache/omarchy")
os.makedirs(cache_dir, exist_ok=True)
net_file = os.path.join(cache_dir, "sysmon_net.json")
today_str = str(date.today())

accum_rx = 0
accum_tx = 0
last_rx = net_rx
last_tx = net_tx
stored_btime = boot_time

try:
    if os.path.exists(net_file):
        with open(net_file, "r") as f:
            sdata = json.load(f)
            if sdata.get("date") == today_str:
                accum_rx = sdata.get("accum_rx", 0)
                accum_tx = sdata.get("accum_tx", 0)
                stored_btime = sdata.get("btime", boot_time)
                old_last_rx = sdata.get("last_rx", net_rx)
                old_last_tx = sdata.get("last_tx", net_tx)

                # Check if reboot occurred today
                if boot_time != stored_btime:
                    accum_rx += old_last_rx
                    accum_tx += old_last_tx
                    stored_btime = boot_time
            else:
                # New day started
                accum_rx = 0
                accum_tx = 0
                stored_btime = boot_time
except Exception:
    pass

# Total today
daily_rx = accum_rx + net_rx
daily_tx = accum_tx + net_tx

try:
    with open(net_file, "w") as f:
        json.dump({
            "date": today_str,
            "btime": stored_btime,
            "accum_rx": accum_rx,
            "accum_tx": accum_tx,
            "last_rx": net_rx,
            "last_tx": net_tx
        }, f)
except Exception:
    pass

# 4. Top CPU & MEM processes
cpu_by_name = defaultdict(float)
mem_by_name = defaultdict(int)
try:
    ps_out = subprocess.check_output(["ps", "-eo", "comm,%cpu,rss", "--no-headers"], text=True)
    for line in ps_out.splitlines():
        parts = line.strip().split()
        if len(parts) >= 3:
            pname = parts[0]
            try:
                cpu_by_name[pname] += float(parts[1])
                mem_by_name[pname] += int(parts[2])
            except ValueError:
                pass
except Exception:
    pass

top_cpu_lines = []
for pname, cval in sorted(cpu_by_name.items(), key=lambda x: x[1], reverse=True)[:4]:
    if cval > 0.05:
        top_cpu_lines.append(f"{get_icon(pname)} {pad(pname[:15], 15)} {rpad(f'{cval:.1f}%', 7)}")

top_mem_lines = []
for pname, kb in sorted(mem_by_name.items(), key=lambda x: x[1], reverse=True)[:4]:
    if kb > 1024:
        top_mem_lines.append(f"{get_icon(pname)} {pad(pname[:15], 15)} {rpad(fmt_b(kb * 1024), 7)}")

# 5. Top Network processes via ss
net_by_name = defaultdict(int)
try:
    ss_out = subprocess.check_output(["ss", "-tup", "-i"], text=True)
    cur_p = None
    for line in ss_out.splitlines():
        if re.search(r"\bESTAB\b", line):
            cur_p = "system"
            m = re.search(r"users:\(\(\"([^\"]+)\"", line)
            if m:
                cur_p = m.group(1)
        elif cur_p and ("bytes_sent:" in line or "bytes_received:" in line):
            m_sent = re.search(r"bytes_sent:(\d+)", line)
            m_recv = re.search(r"bytes_received:(\d+)", line)
            if m_sent:
                net_by_name[cur_p] += int(m_sent.group(1))
            if m_recv:
                net_by_name[cur_p] += int(m_recv.group(1))
except Exception:
    pass

top_net_lines = []
for pname, b in sorted(net_by_name.items(), key=lambda x: x[1], reverse=True)[:4]:
    if b > 1024:
        top_net_lines.append(f"{get_icon(pname)} {pad(pname[:15], 15)} {rpad(fmt_b(b), 7)}")

res = {
    "rx": net_rx,
    "tx": net_tx,
    "idle": idle,
    "total": total,
    "mem_used_kb": mem_used_kb,
    "mem_total_kb": mem_total_kb,
    "mem_pct": mem_pct,
    "swap_used_kb": swap_used_kb,
    "swap_total_kb": swap_total_kb,
    "swap_pct": swap_pct,
    "load": load_str,
    "daily_rx": daily_rx,
    "daily_tx": daily_tx,
    "daily_total_str": fmt_b(daily_rx + daily_tx),
    "daily_rx_str": fmt_b(daily_rx),
    "daily_tx_str": fmt_b(daily_tx),
    "top_cpu_lines": top_cpu_lines,
    "top_mem_lines": top_mem_lines,
    "top_net_lines": top_net_lines
}

print(json.dumps(res))
