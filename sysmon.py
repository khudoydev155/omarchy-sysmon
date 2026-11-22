#!/usr/bin/env python3
import sys, json, os, subprocess, re, time, shutil
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
    if any(x in low for x in ["brave", "chrome", "chromium", "firefox", "zen", "browser", "librewolf", "edge", "opera", "tor"]):
        return ""
    if any(x in low for x in ["telegram", "ayugram", "kotatogram"]):
        return ""
    if any(x in low for x in ["code", "codium", "studio", "android", "idea", "clion", "pycharm", "webstorm", "nvim", "vim"]):
        return "󰅩"
    if any(x in low for x in ["agy", "antigravity", "gemini", "claude", "chatgpt", "ollama"]):
        return "󰚩"
    if any(x in low for x in ["discord", "vesktop", "webcord", "armcord"]):
        return "󰙯"
    if any(x in low for x in ["spotify", "ncspot", "rhythmbox"]):
        return ""
    if any(x in low for x in ["steam", "lutris", "heroic"]):
        return "󰓓"
    if any(x in low for x in ["obs"]):
        return "󰑋"
    if any(x in low for x in ["mpv", "vlc", "yt-dlp", "ffmpeg"]):
        return "󰕼"
    if any(x in low for x in ["curl", "wget", "aria2", "http"]):
        return "󰖟"
    if any(x in low for x in ["git", "gh"]):
        return "󰊢"
    if any(x in low for x in ["ssh", "sshd"]):
        return "󰣀"
    if any(x in low for x in ["thunderbird", "mail"]):
        return "󰇮"
    if any(x in low for x in ["kitty", "foot", "alacritty", "ghostty", "bash", "zsh", "fish", "tmux"]):
        return ""
    if any(x in low for x in ["hypr", "quick", "waybar"]):
        return ""
    if any(x in low for x in ["python"]):
        return ""
    if any(x in low for x in ["btop", "htop"]):
        return "󰓅"
    return "󰣖"

def get_shm_path(filename):
    shm_dir = "/dev/shm"
    if os.path.exists(shm_dir) and os.access(shm_dir, os.W_OK):
        return os.path.join(shm_dir, filename)
    fallback = os.path.expanduser("~/.local/state/omarchy")
    os.makedirs(fallback, exist_ok=True)
    return os.path.join(fallback, filename)

def get_cpu_info():
    model = "Linux Processor"
    cores = 1
    try:
        with open("/proc/cpuinfo", "r") as f:
            lines = f.readlines()
        models = [l.split(":", 1)[1].strip() for l in lines if "model name" in l]
        if models:
            model = models[0]
            cores = len(models)
    except Exception:
        pass
    return model, cores

def get_uptime_str():
    try:
        with open("/proc/uptime", "r") as f:
            up_sec = int(float(f.read().split()[0]))
        h = up_sec // 3600
        m = (up_sec % 3600) // 60
        if h > 24:
            d = h // 24
            rem_h = h % 24
            return f"{d}d {rem_h}h"
        return f"{h}h {m}m"
    except Exception:
        return "0m"

def get_system_stats():
    now_time = time.time()
    shm_proc_file = get_shm_path("sysmon_proc.json")
    shm_sock_file = get_shm_path("sysmon_sockets.json")

    # 1. CPU System Ticks
    idle = 0
    sys_total = 0
    boot_time = 0

    try:
        with open("/proc/stat", "r") as f:
            stat_lines = f.readlines()
        if stat_lines:
            cpu_parts = stat_lines[0].split()
            idle = int(cpu_parts[4]) + int(cpu_parts[5])
            sys_total = sum(int(x) for x in cpu_parts[1:])
            for line in stat_lines:
                if line.startswith("btime "):
                    boot_time = int(line.split()[1])
                    break
    except Exception:
        pass

    # Read current process ticks & memory from /proc directly
    curr_procs = {}
    mem_by_comm = defaultdict(int)

    try:
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
    top_cpu_list = []
    active_cpu = sorted(live_cpu_by_comm.items(), key=lambda x: x[1], reverse=True)
    for comm, pct in active_cpu[:5]:
        if pct >= 0.1:
            top_cpu_lines.append(f"{get_icon(comm)} {pad(comm[:15], 15)} {rpad(f'{pct:.1f}%', 7)}")
            top_cpu_list.append({"name": comm, "icon": get_icon(comm), "pct": round(pct, 1), "pct_str": f"{pct:.1f}%"})

    if not top_cpu_lines:
        top_cpu_lines.append("󰌪 System is idle (<0.1%)")

    # 2. Memory & Swap
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
    top_mem_list = []
    for comm, b in sorted(mem_by_comm.items(), key=lambda x: x[1], reverse=True)[:5]:
        if b > 1024 * 1024:
            pct_mem = round(100.0 * (b / (mem_total_kb * 1024)))
            top_mem_lines.append(f"{get_icon(comm)} {pad(comm[:14], 14)} {rpad(fmt_b(b), 6)} ({pct_mem:>2}%)")
            top_mem_list.append({"name": comm, "icon": get_icon(comm), "bytes": b, "bytes_str": fmt_b(b), "pct": pct_mem})

    # 3. Network Interface Bytes
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

    # 4. Persistent Daily & Monthly Traffic
    state_dir = os.path.expanduser("~/.local/state/omarchy")
    os.makedirs(state_dir, exist_ok=True)
    net_file = os.path.join(state_dir, "sysmon_net.json")
    today_str = str(date.today())
    month_str = today_str[:7]

    daily_rx = 0
    daily_tx = 0
    monthly_rx = 0
    monthly_tx = 0
    apps_data = {}
    stored_btime = boot_time
    is_same_day = False

    if os.path.exists(net_file):
        try:
            with open(net_file, "r") as f:
                sdata = json.load(f)

                if sdata.get("month") == month_str:
                    monthly_rx = sdata.get("monthly_rx", sdata.get("daily_rx", 0))
                    monthly_tx = sdata.get("monthly_tx", sdata.get("daily_tx", 0))
                else:
                    monthly_rx = 0
                    monthly_tx = 0

                if sdata.get("date") == today_str:
                    is_same_day = True
                    stored_btime = sdata.get("btime", boot_time)
                    apps_data = sdata.get("apps", {})
                    old_last_rx = sdata.get("last_rx", net_rx)
                    old_last_tx = sdata.get("last_tx", net_tx)

                    if "daily_rx" in sdata:
                        daily_rx = sdata.get("daily_rx", 0)
                        daily_tx = sdata.get("daily_tx", 0)
                    else:
                        daily_rx = sdata.get("accum_rx", 0)
                        daily_tx = sdata.get("accum_tx", 0)

                    if boot_time == stored_btime:
                        d_rx = max(0, net_rx - old_last_rx)
                        d_tx = max(0, net_tx - old_last_tx)
                    else:
                        d_rx = net_rx
                        d_tx = net_tx
                        stored_btime = boot_time

                    daily_rx += d_rx
                    daily_tx += d_tx
                    monthly_rx += d_rx
                    monthly_tx += d_tx
        except Exception:
            pass

    if not is_same_day:
        boot_date = str(date.fromtimestamp(boot_time)) if boot_time else today_str
        if boot_date == today_str:
            daily_rx = net_rx
            daily_tx = net_tx
        else:
            daily_rx = 0
            daily_tx = 0
        apps_data = {}
        stored_btime = boot_time
        if monthly_rx == 0 and monthly_tx == 0:
            monthly_rx = daily_rx
            monthly_tx = daily_tx

    # Read active sockets from ss (safely checking availability)
    prev_socks = {}
    if os.path.exists(shm_sock_file):
        try:
            with open(shm_sock_file, "r") as f:
                prev_socks = json.load(f)
        except Exception:
            pass

    curr_socks = {}
    if shutil.which("ss"):
        try:
            ss_out = subprocess.check_output(["ss", "-tup", "-i"], text=True, stderr=subprocess.DEVNULL)
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
                        laddr, raddr = parts[4], parts[5]
                        if any(x in laddr or x in raddr for x in ["127.0.0.1", "127.", "[::1]", "::1", "::ffff:127."]):
                            cur_key = None
                            continue
                        cur_key = f"{parts[4]}->{parts[5]}"
                    else:
                        cur_key = f"sock_{len(curr_socks)}"
                elif cur_key and ("bytes_sent:" in line or "bytes_received:" in line):
                    m_sent = re.search(r"bytes_sent:(\d+)", line)
                    m_recv = re.search(r"bytes_received:(\d+)", line)
                    s_val = int(m_sent.group(1)) if m_sent else 0
                    r_val = int(m_recv.group(1)) if m_recv else 0
                    curr_socks[cur_key] = {"proc": cur_p, "tx": s_val, "rx": r_val}

                    if cur_key in prev_socks:
                        p_entry = prev_socks[cur_key]
                        d_tx = max(0, s_val - p_entry.get("tx", 0))
                        d_rx = max(0, r_val - p_entry.get("rx", 0))
                    else:
                        if prev_socks and (s_val + r_val) < 100 * 1024 * 1024:
                            d_tx = s_val
                            d_rx = r_val
                        else:
                            d_tx = 0
                            d_rx = 0

                    if d_tx > 0 or d_rx > 0:
                        if cur_p not in apps_data:
                            apps_data[cur_p] = {"rx": 0, "tx": 0, "total": 0}
                        apps_data[cur_p]["rx"] += d_rx
                        apps_data[cur_p]["tx"] += d_tx
                        apps_data[cur_p]["total"] += (d_rx + d_tx)
        except Exception:
            pass

    try:
        with open(shm_sock_file, "w") as f:
            json.dump(curr_socks, f)
    except Exception:
        pass

    monthly_rx = max(monthly_rx, daily_rx)
    monthly_tx = max(monthly_tx, daily_tx)
    daily_total = daily_rx + daily_tx
    monthly_total = monthly_rx + monthly_tx

    try:
        tmp_file = net_file + ".tmp"
        with open(tmp_file, "w") as f:
            json.dump({
                "date": today_str,
                "month": month_str,
                "btime": stored_btime,
                "daily_rx": daily_rx,
                "daily_tx": daily_tx,
                "monthly_rx": monthly_rx,
                "monthly_tx": monthly_tx,
                "accum_rx": daily_rx,
                "accum_tx": daily_tx,
                "last_rx": net_rx,
                "last_tx": net_tx,
                "apps": apps_data
            }, f, indent=2)
        os.replace(tmp_file, net_file)
    except Exception:
        pass

    top_net_lines = []
    top_net_list = []
    total_apps_bytes = 0
    for pname, pdata in sorted(apps_data.items(), key=lambda x: x[1].get("total", 0), reverse=True):
        tot = pdata.get("total", 0)
        if tot > 1024:
            total_apps_bytes += tot
            top_net_lines.append(f"{get_icon(pname)} {pad(pname[:15], 15)} {rpad(fmt_b(tot), 8)}")
            top_net_list.append({"name": pname, "icon": get_icon(pname), "bytes": tot, "bytes_str": fmt_b(tot)})
        if len(top_net_lines) >= 4:
            break

    other_bytes = max(0, daily_total - total_apps_bytes)
    if other_bytes > 1024 * 1024 and len(top_net_lines) < 5:
        top_net_lines.append(f"󰒋 {pad('other/system', 15)} {rpad(fmt_b(other_bytes), 8)}")
        top_net_list.append({"name": "other/system", "icon": "󰒋", "bytes": other_bytes, "bytes_str": fmt_b(other_bytes)})

    if not top_net_lines:
        top_net_lines.append("󰛳 No app traffic recorded today")

    cpu_model, cpu_cores = get_cpu_info()
    uptime_str = get_uptime_str()

    return {
        "rx": net_rx,
        "tx": net_tx,
        "idle": idle,
        "total": sys_total,
        "cpu_model": cpu_model,
        "cpu_cores": cpu_cores,
        "uptime": uptime_str,
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
        "monthly_rx": monthly_rx,
        "monthly_tx": monthly_tx,
        "monthly_total_str": fmt_b(monthly_total),
        "monthly_rx_str": fmt_b(monthly_rx),
        "monthly_tx_str": fmt_b(monthly_tx),
        "top_cpu_lines": top_cpu_lines,
        "top_mem_lines": top_mem_lines,
        "top_net_lines": top_net_lines,
        "top_cpu_list": top_cpu_list,
        "top_mem_list": top_mem_list,
        "top_net_list": top_net_list
    }

def launch_monitor():
    monitor_cmd = None
    for tool in ["btop", "htop", "top"]:
        if shutil.which(tool):
            monitor_cmd = tool
            break
    if not monitor_cmd:
        monitor_cmd = "top"

    # Priority 1: Omarchy floating terminal presentation wrapper
    if shutil.which("omarchy-launch-floating-terminal-with-presentation"):
        try:
            subprocess.Popen(
                ["omarchy-launch-floating-terminal-with-presentation", monitor_cmd],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            return
        except Exception:
            pass

    # Priority 2: Standard cross-distro terminals (Ubuntu, Debian, Fedora, Arch)
    term_candidates = [
        "xdg-terminal-exec",
        os.environ.get("TERMINAL"),
        "ghostty",
        "kitty",
        "foot",
        "alacritty",
        "wezterm",
        "gnome-terminal",
        "xfce4-terminal",
        "konsole",
        "xterm"
    ]
    for term in term_candidates:
        if term and shutil.which(term):
            try:
                if term in ["gnome-terminal", "xfce4-terminal"]:
                    subprocess.Popen([term, "--", monitor_cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                else:
                    subprocess.Popen([term, "-e", monitor_cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return
            except Exception:
                continue

def print_cli_dashboard(data):
    ram_gb = data["mem_used_kb"] / (1024 * 1024)
    ram_tot_gb = data["mem_total_kb"] / (1024 * 1024)
    swap_gb = data["swap_used_kb"] / (1024 * 1024)
    swap_tot_gb = data["swap_total_kb"] / (1024 * 1024)

    print("┌────────────────────────────────────────────────────────┐")
    print(f"│ 📊 Omarchy System Monitor v1.2.0 (Cross-Distro)        │")
    print("├────────────────────────────────────────────────────────┤")
    print(f"│ CPU:    {data['cpu_model'][:36]} ({data['cpu_cores']} cores)")
    print(f"│ Load:   {data['load']}   •   Uptime: {data['uptime']}")
    print(f"│ Memory: {ram_gb:.1f} GB / {ram_tot_gb:.1f} GB ({data['mem_pct']}%)  •  Swap: {swap_gb:.1f}/{swap_tot_gb:.1f} GB ({data['swap_pct']}%)")
    print(f"│ Traffic Today: {data['daily_total_str']} (↓ {data['daily_rx_str']}  ↑ {data['daily_tx_str']})")
    print(f"│ Traffic Month: {data['monthly_total_str']} (↓ {data['monthly_rx_str']}  ↑ {data['monthly_tx_str']})")
    print("├────────────────────────────────────────────────────────┤")
    print("│ TOP CPU PROCESSES:")
    for line in data["top_cpu_lines"]:
        print(f"│   {line}")
    print("├────────────────────────────────────────────────────────┤")
    print("│ TOP MEMORY PROCESSES:")
    for line in data["top_mem_lines"]:
        print(f"│   {line}")
    print("├────────────────────────────────────────────────────────┤")
    print("│ TOP NETWORK APPS TODAY:")
    for line in data["top_net_lines"]:
        print(f"│   {line}")
    print("└────────────────────────────────────────────────────────┘")

def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "status"

    if action == "launch_monitor":
        launch_monitor()
        return

    data = get_system_stats()

    if action == "waybar":
        # Format for Waybar module
        waybar_payload = {
            "text": f" {data['load'].split(',')[0]}%  󰘚 {data['mem_pct']}%",
            "alt": f"CPU: {data['load']} | RAM: {data['mem_pct']}%",
            "tooltip": (
                f" CPU: {data['cpu_model']} ({data['cpu_cores']} cores)\n"
                f"Load: {data['load']}  •  Uptime: {data['uptime']}\n"
                "─────────────────────────────\n"
                f"󰘚 RAM: {data['mem_used_kb']//1024} MB / {data['mem_total_kb']//1024} MB ({data['mem_pct']}%)\n"
                f"󰓡 Swap: {data['swap_used_kb']//1024} MB / {data['swap_total_kb']//1024} MB ({data['swap_pct']}%)\n"
                "─────────────────────────────\n"
                f"󰛳 Today:   {data['daily_total_str']} (↓ {data['daily_rx_str']}  ↑ {data['daily_tx_str']})\n"
                f"󰛳 Monthly: {data['monthly_total_str']}\n"
                "─────────────────────────────\n"
                "Click: Launch Monitor (btop/htop)"
            ),
            "class": "urgent" if data["mem_pct"] > 90 else "normal",
            "percentage": data["mem_pct"]
        }
        print(json.dumps(waybar_payload))
        return
    elif action in ["cli", "tui", "--help", "-h"]:
        print_cli_dashboard(data)
        return

    print(json.dumps(data))

if __name__ == "__main__":
    main()
