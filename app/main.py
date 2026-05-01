#!/usr/bin/env python3

import json
import logging
import os
import socket
from datetime import datetime, timezone
from typing import Any, Dict, List

from flask import Flask, jsonify

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def get_interfaces() -> List[Dict[str, Any]]:
    """Collect network interface information."""
    import psutil

    interfaces_info = []

    # Get all network interfaces sorted by name
    for interface_name in sorted(psutil.net_if_stats().keys()):
        stats = psutil.net_if_stats()[interface_name]
        addrs = psutil.net_if_addrs().get(interface_name, [])

        # Extract interface index (not directly available in psutil, use name sorting)
        interface_data = {
            "name": interface_name,
            "index": list(sorted(psutil.net_if_stats().keys())).index(interface_name),
            "mac": stats.hwaddr if hasattr(stats, "hwaddr") else "",
            "flags": _get_interface_flags(stats),
            "addresses": sorted([addr.address for addr in addrs]),
        }
        interfaces_info.append(interface_data)

    return interfaces_info


def _get_interface_flags(stats) -> List[str]:
    """Extract interface flags from stats."""
    flags = []
    if stats.isup:
        flags.append("UP")
    if stats.isloopback:
        flags.append("LOOPBACK")
    # Note: psutil doesn't provide all flags that Linux ifconfig does,
    # but we include the main ones
    if hasattr(stats, "broadcast"):
        flags.append("BROADCAST")
    if hasattr(stats, "running") and stats.running:
        flags.append("RUNNING")
    return flags


@app.route("/", methods=["GET"])
@app.route("/interfaces", methods=["GET"])
def interfaces():
    """Return interface information as JSON."""
    try:
        interfaces_list = get_interfaces()
        hostname = socket.gethostname()
        timestamp = datetime.now(timezone.utc).isoformat()

        return jsonify(
            {
                "hostname": hostname,
                "timestamp": timestamp,
                "interfaces": interfaces_list,
            }
        )
    except Exception as e:
        logger.error(f"Error collecting interfaces: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/healthz", methods=["GET"])
def health():
    """Health check endpoint."""
    return "ok\n", 200


if __name__ == "__main__":
    port = os.getenv("PORT", "8080")
    logger.info(f"dummy-upf listening on :{port}")
    app.run(host="0.0.0.0", port=int(port), debug=False)
