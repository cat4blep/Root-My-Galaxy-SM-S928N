#!/usr/bin/env python3
"""Bundle the KTC payload into the published offline EZIF installer APK."""

import argparse
import hashlib
import json
import zipfile
from pathlib import Path

PAYLOAD_ASSET = "assets/ezif/cve-2026-43499-app.so"
FEED_ASSET = "assets/ezif/targets-v3.json"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--payload", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    payload = args.payload.read_bytes()
    payload_sha256 = hashlib.sha256(payload).hexdigest()

    with zipfile.ZipFile(args.input, "r") as source:
        feed = json.loads(source.read(FEED_ASSET))
        if len(feed.get("payloads", [])) != 1:
            raise ValueError("expected exactly one bundled payload")
        profile = feed["payloads"][0]
        if profile.get("exactBuildId") != "CP2A.260605.016.S928NKSU6EZIF":
            raise ValueError("unexpected source firmware profile")

        profile["payloadId"] = "e3q-S928NKSU6EZIF-KTC-v1.3"
        profile["payloadVersion"] = "1.3"
        profile["displayName"] = "Galaxy S24 Ultra SM-S928N | KTC EZIF v1.3"
        profile["exploit"].update(
            size=len(payload),
            sha256=payload_sha256,
        )
        feed_bytes = (json.dumps(feed, indent=2, ensure_ascii=False) + "\n").encode()

        args.output.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(args.output, "w") as destination:
            for info in source.infolist():
                data = source.read(info.filename)
                if info.filename == PAYLOAD_ASSET:
                    data = payload
                elif info.filename == FEED_ASSET:
                    data = feed_bytes

                cloned = zipfile.ZipInfo(info.filename, info.date_time)
                cloned.compress_type = info.compress_type
                cloned.comment = info.comment
                cloned.extra = info.extra
                cloned.internal_attr = info.internal_attr
                cloned.external_attr = info.external_attr
                cloned.create_system = info.create_system
                destination.writestr(cloned, data)

    print(f"payload sha256: {payload_sha256}")
    print(f"unsigned APK: {args.output}")


if __name__ == "__main__":
    main()
