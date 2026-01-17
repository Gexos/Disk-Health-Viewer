r"""
smartread.py v1.1.0

A portable helper for Disk Health Viewer.
- Runs smartctl (smartmontools) and produces an AutoIt-friendly text report.
- Supports Windows oddities where --scan-open uses /dev/sda style names.
- Unifies ATA + NVMe into a single ITEMS table with severity.
- Produces a SUMMARY section (overall + warnings).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from typing import Any, Dict, List, Optional, Tuple


def run_cmd(cmd: List[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")


def scan_open(smartctl: str) -> Tuple[str, str]:
    try:
        p = run_cmd([smartctl, "--scan-open"])
    except FileNotFoundError:
        return "", "smartctl_not_found"
    return (p.stdout or "").strip(), (p.stderr or "").strip()


def extract_physicaldrive_index(device: str) -> Optional[int]:
    m = re.search(r"physicaldrive(\d+)", device.lower())
    if m:
        try:
            return int(m.group(1))
        except ValueError:
            return None
    return None


def parse_scan_lines(scan_out: str) -> List[Tuple[str, str, Optional[str]]]:
    out: List[Tuple[str, str, Optional[str]]] = []
    for line in scan_out.splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        m = re.search(r"^(\S+)\s+-d\s+([A-Za-z0-9_,\-]+)(?:\s+#\s*(.*))?$", s)
        if not m:
            continue
        dev = m.group(1).strip()
        dtype = m.group(2).strip()

        alias = None
        tail = (m.group(3) or "").strip()
        if tail:
            tok = tail.split()[0].rstrip(",")
            if tok.startswith("/dev/") or tok.lower().startswith("\\\\.\\") or tok.lower().startswith("//./"):
                alias = tok

        out.append((dev, dtype, alias))
    return out


def _json_load_or_none(text: str) -> Optional[Dict[str, Any]]:
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


def _find_first(d: Any, paths: List[Tuple[str, ...]]) -> Optional[Any]:
    for path in paths:
        cur = d
        ok = True
        for k in path:
            if isinstance(cur, dict) and k in cur:
                cur = cur[k]
            else:
                ok = False
                break
        if ok and cur is not None:
            return cur
    return None


def _to_int(x: Any) -> Optional[int]:
    try:
        if isinstance(x, bool):
            return int(x)
        if isinstance(x, (int, float)):
            return int(x)
        if isinstance(x, str):
            x = x.strip()
            if x == "":
                return None
            x = re.split(r"[^\d\-]+", x)[0]
            return int(x)
    except Exception:
        return None
    return None


def run_smartctl_json(smartctl: str, dev: str, devtype: Optional[str]) -> Tuple[Optional[Dict[str, Any]], int, str]:
    cmd = [smartctl, "-j", "-a"]
    if devtype:
        cmd += ["-d", devtype]
    cmd.append(dev)
    p = run_cmd(cmd)
    return _json_load_or_none(p.stdout or ""), p.returncode, (p.stderr or "").strip()


def severity_rank(sev: str) -> int:
    s = sev.upper()
    if s == "BAD":
        return 3
    if s == "WARNING":
        return 2
    if s == "OK":
        return 1
    return 0


def score_smart_json(data: Dict[str, Any]) -> int:
    score = 0
    if isinstance(data.get("device"), dict):
        score += 1
    if "model_name" in data or "scsi_model_name" in data:
        score += 1
    if "serial_number" in data or "scsi_serial_number" in data:
        score += 1
    if "ata_smart_attributes" in data:
        score += 4
    if "nvme_smart_health_information_log" in data:
        score += 4

    msgs = data.get("messages")
    if isinstance(msgs, list):
        for m in msgs:
            if not isinstance(m, dict):
                continue
            sev = str(m.get("severity", "")).lower()
            txt = str(m.get("string", "")).lower()
            if sev == "error":
                score -= 2
            if "unable to" in txt or "failed" in txt or "unknown" in txt:
                score -= 1
    return score


def choose_device_and_type(device_arg: str, scan_entries: List[Tuple[str, str, Optional[str]]]) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    idx = extract_physicaldrive_index(device_arg)

    if idx is not None:
        for dev, dtype, alias in scan_entries:
            if f"physicaldrive{idx}" in dev.lower():
                return dev, dtype, alias
        if idx < len(scan_entries):
            dev, dtype, alias = scan_entries[idx]
            return dev, dtype, alias

    return None, None, None


def best_result(smartctl: str, device_arg: str, scan_entries: List[Tuple[str, str, Optional[str]]]) -> Tuple[Dict[str, Any], str, str, int, str, List[str]]:
    preferred_dev, preferred_dtype, preferred_alias = choose_device_and_type(device_arg, scan_entries)

    dev_candidates = [device_arg]
    if preferred_dev and preferred_dev not in dev_candidates:
        dev_candidates.insert(0, preferred_dev)
    if preferred_alias and preferred_alias not in dev_candidates:
        dev_candidates.insert(1, preferred_alias)

    dtype_candidates: List[Optional[str]] = []
    if preferred_dtype:
        dtype_candidates.append(preferred_dtype)
    dtype_candidates += [None, "nvme", "ata", "scsi", "sat"]

    seen = set()
    uniq_dtypes: List[Optional[str]] = []
    for d in dtype_candidates:
        k = d or ""
        if k in seen:
            continue
        seen.add(k)
        uniq_dtypes.append(d)

    best: Optional[Dict[str, Any]] = None
    best_score = -10_000
    attempts: List[str] = []

    for dev in dev_candidates:
        for dtype in uniq_dtypes:
            data, rc, stderr = run_smartctl_json(smartctl, dev, dtype)
            label = f"try dev={dev} dtype={(dtype or '')} rc={rc}"
            if data is None:
                attempts.append(label + " -> no_json")
                continue

            data["_rc"] = rc
            data["_stderr"] = stderr
            data["_used_dev"] = dev
            data["_used_dtype"] = dtype or ""

            sc = score_smart_json(data)
            attempts.append(label + f" score={sc}")

            if sc > best_score:
                best_score = sc
                best = data

            if sc >= 6:
                break
        if best_score >= 6:
            break

    if best is None:
        raise RuntimeError("smartctl_no_json_output")

    return best, str(best.get("_used_dev", "")), str(best.get("_used_dtype", "")), int(best.get("_rc", 0) or 0), str(best.get("_stderr", "")), attempts


def extract_overview(data: Dict[str, Any], device_arg: str) -> Dict[str, str]:
    model = str(_find_first(data, [
        ("model_name",),
        ("model_family",),
        ("device", "model_name"),
        ("scsi_model_name",),
    ]) or "-")

    serial = str(_find_first(data, [
        ("serial_number",),
        ("device", "serial_number"),
        ("scsi_serial_number",),
    ]) or "-")

    protocol = str(_find_first(data, [
        ("device", "protocol"),
        ("device", "type"),
    ]) or "-")

    smart_passed = _find_first(data, [("smart_status", "passed")])
    if isinstance(smart_passed, bool):
        health = "PASSED" if smart_passed else "FAILED"
    else:
        health = "UNKNOWN"

    temp = _find_first(data, [
        ("temperature", "current"),
        ("temperature", "current_celsius"),
        ("nvme_smart_health_information_log", "temperature"),
    ])
    temperature_c = str(int(temp)) if isinstance(temp, (int, float)) else "-"

    poh = _find_first(data, [
        ("power_on_time", "hours"),
        ("nvme_smart_health_information_log", "power_on_hours"),
    ])
    power_on_hours = str(int(poh)) if isinstance(poh, (int, float)) else "-"

    return {
        "device": device_arg,
        "model": model,
        "serial": serial,
        "health": health,
        "temperature_c": temperature_c,
        "power_on_hours": power_on_hours,
        "protocol": protocol,
        "smartctl_rc": str(data.get("_rc", "")),
        "smartctl_dev": str(data.get("_used_dev", "")),
        "smartctl_devtype": str(data.get("_used_dtype", "")),
    }


def ata_attr_severity(attr_id: int, raw_val: Optional[int], value: Optional[int], thresh: Optional[int]) -> Tuple[str, str]:
    if raw_val is None:
        return "UNKNOWN", ""
    bad_if_nonzero = {197, 198}
    warn_if_nonzero = {5, 187, 188, 196, 199}

    if attr_id in bad_if_nonzero and raw_val > 0:
        return "BAD", "raw>0"
    if attr_id in warn_if_nonzero and raw_val > 0:
        return "WARNING", "raw>0"

    if value is not None and thresh is not None and thresh > 0 and value <= thresh:
        return "BAD", "value<=thresh"

    return "OK", ""


def extract_ata_items(data: Dict[str, Any]) -> Tuple[List[List[str]], List[str]]:
    warnings: List[str] = []
    table = _find_first(data, [("ata_smart_attributes", "table")])
    if not isinstance(table, list):
        return [], warnings

    items: List[List[str]] = []
    for row in table:
        if not isinstance(row, dict):
            continue
        rid = _to_int(row.get("id"))
        name = str(row.get("name") or "")
        value = _to_int(row.get("value"))
        worst = _to_int(row.get("worst"))
        thresh = _to_int(row.get("thresh"))
        raw = row.get("raw", {})
        raw_val = raw.get("value") if isinstance(raw, dict) else raw
        raw_int = _to_int(raw_val)

        sev, reason = ("UNKNOWN", "")
        if rid is not None:
            sev, reason = ata_attr_severity(rid, raw_int, value, thresh)

        if sev in ("WARNING", "BAD"):
            msg = f"ATA {rid} {name}: {reason} (raw={raw_int})" if rid is not None else f"ATA {name}: {reason}"
            warnings.append(msg)

        items.append([
            str(rid) if rid is not None else "",
            name.replace("|", "/"),
            str(value) if value is not None else "",
            str(worst) if worst is not None else "",
            str(thresh) if thresh is not None else "",
            sev,
            str(raw_val).replace("|", "/").replace("\n", " ").strip(),
        ])
    return items, warnings


def nvme_severity(log: Dict[str, Any]) -> Tuple[str, List[str]]:
    warnings: List[str] = []
    overall = "OK"

    def bump(new: str):
        nonlocal overall
        if severity_rank(new) > severity_rank(overall):
            overall = new

    crit = _to_int(log.get("critical_warning"))
    if crit is not None and crit != 0:
        bump("BAD")
        warnings.append(f"NVMe critical_warning={crit}")

    pct = _to_int(log.get("percentage_used"))
    if pct is not None:
        if pct >= 100:
            bump("BAD")
            warnings.append(f"NVMe percentage_used={pct}%")
        elif pct >= 80:
            bump("WARNING")
            warnings.append(f"NVMe percentage_used={pct}%")

    media = _to_int(log.get("media_errors"))
    if media is not None and media > 0:
        bump("BAD")
        warnings.append(f"NVMe media_errors={media}")

    spare = _to_int(log.get("available_spare"))
    spare_thr = _to_int(log.get("available_spare_threshold"))
    if spare is not None and spare_thr is not None and spare <= spare_thr:
        bump("BAD")
        warnings.append(f"NVMe available_spare={spare}% (threshold {spare_thr}%)")

    temp = _to_int(log.get("temperature"))
    if temp is not None:
        if temp >= 80:
            bump("BAD")
            warnings.append(f"NVMe temperature={temp}C")
        elif temp >= 70:
            bump("WARNING")
            warnings.append(f"NVMe temperature={temp}C")

    errlog = _to_int(log.get("num_err_log_entries"))
    if errlog is not None and errlog > 0:
        bump("WARNING")
        warnings.append(f"NVMe err_log_entries={errlog}")

    return overall, warnings


def extract_nvme_items(data: Dict[str, Any]) -> Tuple[List[List[str]], List[str], str]:
    log = _find_first(data, [("nvme_smart_health_information_log",)])
    if not isinstance(log, dict):
        return [], [], "UNKNOWN"

    overall, warns = nvme_severity(log)

    keys = [
        "critical_warning",
        "temperature",
        "available_spare",
        "available_spare_threshold",
        "percentage_used",
        "data_units_read",
        "data_units_written",
        "host_reads",
        "host_writes",
        "controller_busy_time",
        "power_cycles",
        "power_on_hours",
        "unsafe_shutdowns",
        "media_errors",
        "num_err_log_entries",
    ]

    items: List[List[str]] = []
    for k in keys:
        if k not in log:
            continue
        v = log.get(k)
        v_str = json.dumps(v, ensure_ascii=False) if isinstance(v, (dict, list)) else str(v)

        sev = "OK"
        if k == "critical_warning":
            sev = "BAD" if _to_int(v) not in (None, 0) else "OK"
        elif k == "percentage_used":
            pct = _to_int(v)
            if pct is None:
                sev = "UNKNOWN"
            elif pct >= 100:
                sev = "BAD"
            elif pct >= 80:
                sev = "WARNING"
        elif k == "media_errors":
            sev = "BAD" if (_to_int(v) or 0) > 0 else "OK"
        elif k == "temperature":
            t = _to_int(v)
            if t is None:
                sev = "UNKNOWN"
            elif t >= 80:
                sev = "BAD"
            elif t >= 70:
                sev = "WARNING"
        elif k == "num_err_log_entries":
            sev = "WARNING" if (_to_int(v) or 0) > 0 else "OK"
        elif k == "available_spare":
            spare = _to_int(v)
            thr = _to_int(log.get("available_spare_threshold"))
            if spare is None or thr is None:
                sev = "UNKNOWN"
            elif spare <= thr:
                sev = "BAD"

        items.append(["", f"NVMe {k}", v_str, "", "", sev, v_str])
    return items, warns, overall


def overall_summary(ata_warns: List[str], nvme_warns: List[str], smart_status: str, nvme_overall: str) -> Tuple[str, List[str]]:
    warnings = ata_warns + nvme_warns
    overall = "OK"

    if smart_status == "FAILED":
        overall = "BAD"
        warnings = ["SMART status FAILED"] + warnings

    if severity_rank(nvme_overall) > severity_rank(overall):
        overall = nvme_overall

    if overall != "BAD" and warnings:
        overall = "WARNING"

    if smart_status == "UNKNOWN" and overall == "OK" and not warnings:
        overall = "UNKNOWN"

    return overall, warnings


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--device", required=True)
    ap.add_argument("--smartctl", required=True)
    args = ap.parse_args()

    smartctl = os.path.abspath(args.smartctl)
    device_arg = args.device

    print("#SMARTREADv110")

    if not os.path.exists(smartctl):
        print("OVERVIEW")
        print(f"device={device_arg}")
        print("health=ERROR (smartctl.exe not found)")
        print("SUMMARY")
        print("overall=BAD")
        print("warnings=smartctl.exe not found")
        return 2

    scan_out, scan_err = scan_open(smartctl)
    scan_entries = parse_scan_lines(scan_out)

    try:
        data, used_dev, used_dtype, rc, stderr, attempts = best_result(smartctl, device_arg, scan_entries)
    except RuntimeError as e:
        print("OVERVIEW")
        print(f"device={device_arg}")
        print(f"health=ERROR ({e})")
        print("SUMMARY")
        print("overall=BAD")
        print(f"warnings={e}")
        return 3

    ov = extract_overview(data, device_arg)
    ata_items, ata_warns = extract_ata_items(data)
    nvme_items, nvme_warns, nvme_overall = extract_nvme_items(data)

    overall, warnings = overall_summary(ata_warns, nvme_warns, ov.get("health", "UNKNOWN"), nvme_overall)

    print("OVERVIEW")
    for k in ["device", "model", "serial", "health", "temperature_c", "power_on_hours", "protocol", "smartctl_rc", "smartctl_dev", "smartctl_devtype"]:
        print(f"{k}={ov.get(k, '-')}")
    if stderr:
        err = " ".join(stderr.split())
        print(f"smartctl_stderr={err[:300]}")

    print("SUMMARY")
    print(f"overall={overall}")
    print("warnings=" + ("; ".join(warnings)[:1200] if warnings else ""))

    print("ITEMS")
    print("id|name|value|worst|thresh|severity|raw")
    all_items = ata_items + nvme_items
    all_items.sort(key=lambda r: (-severity_rank(r[5]), r[1].lower()))
    for r in all_items:
        print("|".join([c.replace("\n", " ").strip() for c in r]))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
