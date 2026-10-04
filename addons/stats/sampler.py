#!/usr/bin/env python3
# System Stats' reader: prints one JSON line every five seconds (the first a
# second in) with the CPU, memory, GPU, storage, temperature and process
# figures the page shows. Run only while Settings is open (see StatsAddon.qml); reads /proc
# and /sys, plus nvidia-smi when an NVIDIA card is present. Needs no root:
# what only root can read (other users' disk I/O, RAPL power) is left out.
import glob
import json
import os
import signal
import socket
import subprocess
import sys
import threading
import time

TICK = 5.0
CLK = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
ME = os.getuid()
PARENT = os.getppid()


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return default


def number(path, default=None):
    try:
        return float(read(path).strip())
    except ValueError:
        return default


# CPU ------------------------------------------------------------------------

def cpu_times():
    # The whole CPU's (user, system, idle) time since boot.
    v = [int(x) for x in read("/proc/stat").split("\n", 1)[0].split()[1:9]]
    return v[0] + v[1], v[2] + v[5] + v[6] + v[7], v[3] + v[4]


# The package's sensor names, best first: AMD's Tctl carries a fixed offset on
# some chips (27 °C on early Threadrippers), so the die's own Tdie wins.
CPU_LABELS = ("Tdie", "Package id 0", "Tctl", "")


def cpu_temp_path():
    # The package's temperature file from its hwmon driver, found once.
    for mon in glob.glob("/sys/class/hwmon/hwmon*"):
        if read(mon + "/name").strip() not in ("k10temp", "zenpower", "coretemp"):
            continue
        found = {}
        for path in glob.glob(mon + "/temp*_input"):
            label = read(path.replace("_input", "_label")).strip()
            if label in CPU_LABELS and number(path) is not None:
                found.setdefault(label, path)
        for label in CPU_LABELS:
            if label in found:
                return found[label]
    return None


def cpu_temp(path):
    # The package's temperature, in °C.
    value = number(path) if path else None
    return value / 1000 if value is not None else None


# Memory ---------------------------------------------------------------------

def memory():
    info = {}
    for line in read("/proc/meminfo").splitlines():
        key, _, rest = line.partition(":")
        info[key] = int(rest.split()[0]) * 1024
    total = info.get("MemTotal", 0)
    pressure = 0.0
    for line in read("/proc/pressure/memory").splitlines():
        if line.startswith("some"):
            pressure = float(line.split()[1].split("=")[1])
    return {
        "total": total, "used": total - info.get("MemAvailable", 0),
        "swapTotal": info.get("SwapTotal", 0), "swapUsed": info.get("SwapTotal", 0) - info.get("SwapFree", 0),
        "pressure": pressure,
    }


# Disks ----------------------------------------------------------------------

def ssd_paths():
    # Each NVMe drive's overall temperature file (its Composite sensor),
    # found once.
    return [mon + "/temp1_input" for mon in sorted(glob.glob("/sys/class/hwmon/hwmon*"))
            if read(mon + "/name").strip() == "nvme"]


def ssd_temps(paths):
    # Each drive's temperature, in °C. Reading one asks the drive itself, so
    # this runs only every SSD_EVERY seconds.
    temps = []
    for path in paths:
        value = number(path)
        if value is not None and value > 0:
            temps.append(value / 1000)
    return temps


SKIP_MOUNTS = ("/boot", "/efi")
REAL_FS = {"ext4", "ext3", "btrfs", "xfs", "f2fs", "vfat", "exfat", "ntfs3", "ntfs", "zfs", "bcachefs"}


def volumes():
    seen, result = set(), []
    for line in read("/proc/self/mounts").splitlines():
        source, target, fstype = line.split()[:3]
        target = target.replace("\\040", " ")
        if fstype not in REAL_FS or source in seen or target.startswith(SKIP_MOUNTS):
            continue
        seen.add(source)
        try:
            st = os.statvfs(target)
        except OSError:
            continue
        size = st.f_blocks * st.f_frsize
        if size == 0:
            continue
        result.append({"mount": target, "device": os.path.basename(source),
                       "size": size, "used": size - st.f_bfree * st.f_frsize})
    return result


# GPU ------------------------------------------------------------------------

class NvidiaWatch:
    # nvidia-smi is slow to start, so its loop is left running and its
    # latest lines kept.
    QUERY = "name,utilization.gpu,memory.used,memory.total,temperature.gpu,clocks.gr,power.draw,fan.speed"

    def __init__(self):
        self.gpus = {}
        self.children = []
        self.spawn(["nvidia-smi", "--query-gpu=index," + self.QUERY, "--format=csv,noheader,nounits", "-lms", str(int(TICK * 1000))], self.on_query)

    def spawn(self, cmd, handler):
        try:
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        except OSError:
            return
        self.children.append(p)
        threading.Thread(target=self.pump, args=(p, handler), daemon=True).start()

    def pump(self, p, handler):
        for line in p.stdout:
            try:
                handler(line)
            except (ValueError, IndexError):
                pass

    def on_query(self, line):
        f = [x.strip() for x in line.split(",")]

        def num(x):
            try:
                return float(x)
            except ValueError:
                return None
        self.gpus[f[0]] = {
            "name": f[1], "vendor": "NVIDIA", "usage": num(f[2]),
            "vramUsed": (num(f[3]) or 0) * 1048576, "vramTotal": (num(f[4]) or 0) * 1048576,
            "temp": num(f[5]), "clock": num(f[6]), "power": num(f[7]), "fan": num(f[8]),
        }

    def stop(self):
        for p in self.children:
            p.terminate()


def drm_cards():
    cards = []
    for card in sorted(glob.glob("/sys/class/drm/card[0-9]")):
        dev = card + "/device"
        vendor = read(dev + "/vendor").strip()
        if vendor:
            cards.append((card, dev, vendor))
    return cards


def hwmon_of(dev):
    found = glob.glob(dev + "/hwmon/hwmon*")
    return found[0] if found else None


def drm_gpu(card, dev, vendor, busy):
    name = {"0x1002": "AMD", "0x8086": "Intel"}.get(vendor, "GPU")
    gpu = {"name": name + " Graphics", "vendor": name, "usage": None, "vramUsed": None, "vramTotal": None,
           "temp": None, "clock": None, "power": None, "fan": None}
    if os.path.exists(dev + "/gpu_busy_percent"):
        gpu["usage"] = number(dev + "/gpu_busy_percent")
    elif busy is not None:
        gpu["usage"] = min(100.0, busy)
    if os.path.exists(dev + "/mem_info_vram_total"):
        gpu["vramUsed"] = number(dev + "/mem_info_vram_used")
        gpu["vramTotal"] = number(dev + "/mem_info_vram_total")
    for line in read(dev + "/pp_dpm_sclk").splitlines():
        if line.rstrip().endswith("*"):
            gpu["clock"] = float(line.split()[1].lower().replace("mhz", ""))
    if gpu["clock"] is None:
        gpu["clock"] = number(card + "/gt_cur_freq_mhz")
    mon = hwmon_of(dev)
    if mon:
        t = number(mon + "/temp1_input")
        gpu["temp"] = t / 1000 if t is not None else None
        p = number(mon + "/power1_average") or number(mon + "/power1_input")
        gpu["power"] = p / 1e6 if p is not None else None
    return gpu


def drm_fds(pid):
    # The fds this process holds on a DRM device.
    fds = []
    base = "/proc/%d/fd/" % pid
    try:
        names = os.listdir(base)
    except OSError:
        return fds
    for fd in names:
        try:
            if "/dev/dri/" in os.readlink(base + fd):
                fds.append(fd)
        except OSError:
            continue
    return fds


def drm_clients(pid, fds, pdevs):
    # Each DRM client this process holds through these fds on one of these
    # cards (PCI addresses): {client id: busiest engine's ns}.
    clients = {}
    for fd in fds:
        cid, busiest, pdev = None, 0, None
        for line in read("/proc/%d/fdinfo/%s" % (pid, fd)).splitlines():
            if line.startswith("drm-client-id:"):
                cid = line.split()[1]
            elif line.startswith("drm-pdev:"):
                pdev = line.split()[1]
            elif line.startswith("drm-engine-") and line.endswith(" ns"):
                busiest = max(busiest, int(line.split()[1]))
        if cid and (pdev is None or pdev in pdevs):
            clients[cid] = busiest
    return clients


# Processes ------------------------------------------------------------------

class WindowWatch:
    # hyprctl clients is run again only once Hyprland's event socket says a
    # window opened or closed; every tick if the socket can't be reached.
    EVENTS = (b"openwindow>>", b"closewindow>>")

    def __init__(self):
        self.dirty = threading.Event()
        self.dirty.set()
        self.live = False
        self.cached = {}
        path = os.path.join(os.environ.get("XDG_RUNTIME_DIR", ""), "hypr",
                            os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", ""), ".socket2.sock")
        try:
            self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.sock.connect(path)
        except OSError:
            return
        self.live = True
        threading.Thread(target=self.listen, daemon=True).start()

    def listen(self):
        try:
            with self.sock.makefile("rb") as events:
                for line in events:
                    if line.startswith(self.EVENTS):
                        self.dirty.set()
        except OSError:
            pass
        self.live = False

    def get(self):
        if self.live and not self.dirty.is_set():
            return self.cached
        # Cleared first, so an event during the query asks again next tick.
        self.dirty.clear()
        self.cached = windows()
        if not self.cached:
            self.dirty.set()
        return self.cached


def windows():
    # Each open window's process: {pid: class}.
    try:
        out = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=2).stdout
        return {c["pid"]: c.get("class") or c.get("initialClass") or "" for c in json.loads(out) if c.get("pid", -1) > 0}
    except (OSError, ValueError, subprocess.SubprocessError):
        return {}


def processes():
    procs = {}
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)
        stat = read("/proc/%d/stat" % pid)
        if not stat:
            continue
        close = stat.rfind(")")
        comm = stat[stat.find("(") + 1:close]
        f = stat[close + 2:].split()
        # f[0] is state, so field n of stat(5) is f[n - 3].
        ppid = int(f[1])
        kernel = pid == 2 or ppid == 2
        try:
            uid = os.stat("/proc/%d" % pid).st_uid
        except OSError:
            continue
        procs[pid] = {
            "pid": pid, "ppid": ppid, "uid": uid, "comm": comm, "kernel": kernel, "start": int(f[19]),
            "ticks": int(f[11]) + int(f[12]), "threads": int(f[17]), "rss": int(f[21]) * PAGE,
        }
    return procs


def process_name(pid, comm):
    if len(comm) < 15:
        return comm
    argv0 = read("/proc/%d/cmdline" % pid).split("\0")[0]
    return os.path.basename(argv0) or comm


# Main loop ------------------------------------------------------------------

FD_RESCAN = 30.0
SSD_EVERY = 30.0


def drm_usage(procs, fd_cache, pdevs, now):
    # Each of your processes' DRM clients: {(pid, start): {client id: ns}}.
    # Which fds are DRM ones is rescanned only every FD_RESCAN seconds, as
    # listing every fd of every process each tick is costly.
    usage = {}
    for pid, p in procs.items():
        if p["kernel"] or p["uid"] != ME:
            continue
        key = (pid, p["start"])
        fds, at = fd_cache.get(key, (None, 0))
        if fds is None or now - at > FD_RESCAN:
            fds, at = drm_fds(pid), now
            fd_cache[key] = (fds, at)
        if fds:
            usage[key] = drm_clients(pid, fds, pdevs)
    for key in [k for k in fd_cache if k[0] not in procs or procs[k[0]]["start"] != k[1]]:
        del fd_cache[key]
    return usage

def main():
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    cards = drm_cards()
    nvidia = NvidiaWatch() if any(v == "0x10de" for _, _, v in cards) else None
    others = [c for c in cards if c[2] != "0x10de"]
    # The other cards' PCI addresses, so an NVIDIA card's clients aren't
    # counted as theirs.
    other_pdevs = {os.path.basename(os.path.realpath(dev)) for _, dev, _ in others}
    # Primed, so the first reading's per-process figures are real ones.
    names, fd_cache = {}, {}
    procs = processes()
    last_cpu = cpu_times()
    last_ticks = {(pid, p["start"]): p["ticks"] for pid, p in procs.items()}
    last_time = time.monotonic()
    drm = {}
    if others:
        for clients in drm_usage(procs, fd_cache, other_pdevs, last_time).values():
            drm.update(clients)
    vols, vols_at = [], 0
    temp_path, ssds = cpu_temp_path(), ssd_paths()
    ssd, ssd_at = [], 0
    window_watch = WindowWatch()
    try:
        first = True
        while True:
            time.sleep(1.0 if first else TICK)
            first = False
            if os.getppid() != PARENT:
                break
            now = time.monotonic()
            elapsed = max(0.001, now - last_time)
            last_time = now

            times = cpu_times()
            spent = [t - was for t, was in zip(times, last_cpu)]
            total = max(1, sum(spent))
            overall = (100 * spent[0] / total, 100 * spent[1] / total)
            last_cpu = times

            if now - vols_at > 10:
                vols, vols_at = volumes(), now

            if now - ssd_at > SSD_EVERY:
                ssd, ssd_at = ssd_temps(ssds), now

            win = window_watch.get()

            procs = processes()
            usage = drm_usage(procs, fd_cache, other_pdevs, now) if others else {}
            kernel = {"pid": 2, "ppid": 0, "uid": 0, "name": "kernel", "cpu": 0.0, "mem": 0,
                      "threads": 0, "app": None, "appClass": ""}
            rows = []
            busy_total = 0.0
            seen_clients = set()
            new_drm = {}
            for pid, p in procs.items():
                ticks = p["ticks"]
                cpu = 100 * (ticks - last_ticks.get((pid, p["start"]), ticks)) / CLK / elapsed
                if p["kernel"]:
                    kernel["cpu"] += cpu
                    kernel["threads"] += p["threads"]
                    continue
                key = (pid, p["comm"])
                if key not in names:
                    names[key] = process_name(pid, p["comm"])
                # An AMD or Intel GPU's busy share, for its card, as the sum of
                # what each of your processes keeps it busy (also beside an
                # NVIDIA card, whose own figures come from nvidia-smi).
                if (pid, p["start"]) in usage:
                    gpu = 0.0
                    for cid, ns in usage[(pid, p["start"])].items():
                        if cid in seen_clients:
                            continue
                        seen_clients.add(cid)
                        new_drm[cid] = ns
                        share = 100 * (ns - drm.get(cid, ns)) / (elapsed * 1e9)
                        gpu = max(gpu, share)
                    busy_total += gpu
                # The window this process belongs to: itself or its nearest
                # ancestor with one.
                app, cur, hops = None, pid, 0
                while cur > 1 and hops < 64:
                    if cur in win:
                        app = cur
                        break
                    cur = procs[cur]["ppid"] if cur in procs else 0
                    hops += 1
                rows.append({"pid": pid, "ppid": p["ppid"], "uid": p["uid"], "start": p["start"], "name": names[key],
                             "cpu": round(cpu, 1), "mem": p["rss"],
                             "threads": p["threads"], "app": app,
                             "appClass": win.get(pid, "") if app == pid else ""})
            kernel["cpu"] = round(kernel["cpu"], 1)
            rows.append(kernel)
            last_ticks = {(pid, p["start"]): p["ticks"] for pid, p in procs.items()}
            drm = new_drm
            names = {k: v for k, v in names.items() if k[0] in procs}

            gpus = list(nvidia.gpus.values()) if nvidia else []
            for card, dev, vendor in others:
                gpus.append(drm_gpu(card, dev, vendor, busy_total if len(others) == 1 else None))

            print(json.dumps({
                "uid": ME,
                "cpu": {"user": round(overall[0], 1), "system": round(overall[1], 1),
                        "idle": round(max(0.0, 100 - overall[0] - overall[1]), 1), "temp": cpu_temp(temp_path)},
                "memory": memory(),
                "gpus": gpus,
                "volumes": vols, "ssdTemps": ssd,
                "processes": rows,
            }, separators=(",", ":")), flush=True)
    except (BrokenPipeError, KeyboardInterrupt, SystemExit):
        pass
    finally:
        if nvidia:
            nvidia.stop()


if __name__ == "__main__":
    main()
