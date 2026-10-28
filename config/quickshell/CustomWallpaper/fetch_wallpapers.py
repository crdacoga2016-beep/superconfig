#!/usr/bin/env python3
"""Small JSON-lines backend for the CustomWallpaper Quickshell UI."""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

UA = "Mozilla/5.0 (Linux; Hyprland) CustomWallpaper/1.1"

VIDEO_EXTS = {".mp4", ".webm", ".mkv", ".mov", ".gif"}
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".avif"}
WALLPAPER_EXTS = VIDEO_EXTS | IMAGE_EXTS


def request(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json,text/html,*/*"})
    with urllib.request.urlopen(req, timeout=25) as response:
        return response.read()


def request_with_type(url: str) -> tuple[bytes, str, str]:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json,text/html,*/*"})
    with urllib.request.urlopen(req, timeout=90) as response:
        return response.read(), response.headers.get_content_type(), response.geturl()


def emit(items: list[dict]) -> None:
    for item in items:
        print(json.dumps(item, ensure_ascii=False))


def data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local" / "share")))


def cache_home() -> Path:
    return Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))


def config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))


def runtime_dir() -> Path:
    return Path(os.environ.get("XDG_RUNTIME_DIR", f"/tmp/custom-wallpaper-{os.getuid()}"))


# Matches Caelestia's djb2 hash so existing video thumbnails are reused.
def djb2(value: str) -> str:
    result = 5381
    for char in value:
        result = ((result << 5) + result) + ord(char)
        result &= 0xFFFFFFFF
    return str(result)


def wallpaper_dir() -> Path:
    configured = None
    try:
        config = json.loads((config_home() / "caelestia" / "shell.json").read_text())
        configured = config.get("paths", {}).get("wallpaperDir")
    except (OSError, json.JSONDecodeError):
        pass

    candidates = [Path(configured).expanduser()] if configured else []
    candidates += [
        Path.home() / "Vídeos",
        Path.home() / "Videos",
        Path.home() / "Pictures" / "Wallpapers",
        Path.home() / "Pictures",
    ]
    for candidate in candidates:
        if candidate.is_dir():
            return candidate
    return Path.home()


def pretty_name(stem: str) -> str:
    clean = re.sub(r"\.\d{3,4}x\d{3,4}$", "", stem)
    clean = re.sub(r"[_-]+", " ", clean).strip()
    return clean[:1].upper() + clean[1:] if clean else stem


def video_thumbnail(path: Path) -> str:
    existing = cache_home() / "caelestia" / "videothumbs" / (djb2(str(path)) + ".jpg")
    if existing.is_file() and existing.stat().st_size > 0:
        return existing.as_uri()

    folder = cache_home() / "custom-wallpaper" / "thumbs"
    folder.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha1(f"{path}:{path.stat().st_mtime}".encode()).hexdigest()
    target = folder / (digest + ".jpg")
    if not target.is_file() or target.stat().st_size == 0:
        if not shutil.which("ffmpeg"):
            return path.as_uri()
        subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-ss", "1", "-i", str(path),
             "-frames:v", "1", "-vf", "scale=960:-2", str(target)],
            check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    return target.as_uri() if target.is_file() and target.stat().st_size > 0 else path.as_uri()


def local_wallpapers(query: str, browse_filter: str) -> list[dict]:
    folder = wallpaper_dir()
    out: list[dict] = []
    try:
        entries = sorted(folder.iterdir(), key=lambda p: p.name.lower())
    except OSError:
        return out

    wanted = (query or "").strip().lower()
    for path in entries:
        if not path.is_file() or path.name.startswith("."):
            continue
        suffix = path.suffix.lower()
        if suffix not in WALLPAPER_EXTS:
            continue
        if wanted and wanted not in path.name.lower():
            continue
        animated = suffix in VIDEO_EXTS
        if browse_filter == "animated" and not animated:
            continue
        if browse_filter == "static" and animated:
            continue

        resolution = ""
        match = re.search(r"(\d{3,4})x(\d{3,4})", path.stem)
        if match:
            resolution = f"{match.group(1)}×{match.group(2)}"

        out.append({
            "id": str(path),
            "title": pretty_name(path.stem),
            "thumb": video_thumbnail(path) if animated else path.as_uri(),
            "preview": path.as_uri() if animated else "",
            "full": str(path),
            "pageUrl": "",
            "resolution": resolution or ("Animated" if animated else "Image"),
            "source": "local",
            "animated": animated,
        })
    return out


def motionbgs(query: str, page: int, browse_filter: str) -> list[dict]:
    if query.strip():
        url = "https://motionbgs.com/search?q=" + urllib.parse.quote_plus(query.strip())
    elif browse_filter in {"anime", "games", "nature", "landscape"}:
        url = f"https://motionbgs.com/tag:{browse_filter}/"
    elif browse_filter == "4k":
        url = "https://motionbgs.com/4k/"
    else:
        url = "https://motionbgs.com/"

    body = request(url).decode("utf-8", "replace")
    out: list[dict] = []
    seen: set[str] = set()

    for match in re.finditer(r'<a title="([^"]+)" href=/([a-z0-9-]+)>(.*?)</a>', body, re.I | re.S):
        title, slug, block = html.unescape(match.group(1)), match.group(2), match.group(3)
        media = re.search(r'/i/c/[0-9]+x[0-9]+/(media/(\d+)/[^ "><]+?\.(?:jpg|jpeg|png|webp))', block, re.I)
        if not media:
            media = re.search(r'(media/(\d+)/[^ "><]+?\.(?:jpg|jpeg|png|webp))', block, re.I)
        if not media:
            continue

        ident = media.group(2)
        if ident in seen:
            continue
        seen.add(ident)

        # The poster name carries the real slug used by the 960p preview stream.
        poster = media.group(1).rsplit("/", 1)[-1]
        base = re.sub(r"(\.\d{3,4}x\d{3,4})?\.(?:jpg|jpeg|png|webp)$", "", poster, flags=re.I)
        quality = re.search(r'class=frm>\s*([^<]+?)\s*<', block, re.I)

        out.append({
            "id": ident,
            "title": re.sub(r"\s+live wallpaper$", "", title, flags=re.I),
            "thumb": "https://motionbgs.com/i/c/546x308/" + media.group(1),
            "preview": f"https://motionbgs.com/media/{ident}/{base}.960x540.mp4",
            "full": f"https://motionbgs.com/dl/4k/{ident}",
            "pageUrl": f"https://motionbgs.com/{slug}",
            "resolution": (quality.group(1) if quality else "4K"),
            "source": "motionbgs",
            "animated": True,
        })
        if len(out) >= 60:
            break
    return out


def _runtime_thumbnail(item: dict) -> dict:
    """Fetch a hotlink-protected preview into the per-login runtime cache."""
    folder = runtime_dir() / "custom-wallpaper-thumbnails"
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / (re.sub(r"[^a-zA-Z0-9_-]", "-", item["id"])[:90] + ".jpg")
    try:
        if not target.exists() or target.stat().st_size == 0:
            target.write_bytes(request(item["thumb"]))
        item["thumb"] = target.as_uri()
    except OSError:
        pass
    return item


def cache_moe_thumbnails(items: list[dict]) -> list[dict]:
    # Parallel requests keep a 30-card page from waiting on each image in turn.
    with ThreadPoolExecutor(max_workers=8) as pool:
        return list(pool.map(_runtime_thumbnail, items))


def wallhaven(query: str, page: int, purity: str, browse_filter: str) -> list[dict]:
    params = {
        "q": query,
        "page": str(page),
        "sorting": "relevance" if query else ("toplist" if browse_filter == "toplist" else "date_added"),
        "order": "desc",
        "purity": purity,
        "atleast": "1920x1080",
    }
    url = "https://wallhaven.cc/api/v1/search?" + urllib.parse.urlencode(params)
    payload = json.loads(request(url))
    return [{
        "id": row["id"],
        "title": "Wallhaven · " + row["id"],
        "thumb": row["thumbs"]["large"],
        "preview": "",
        "full": row["path"],
        "pageUrl": row["url"],
        "resolution": row.get("resolution", ""),
        "source": "wallhaven",
        "animated": False,
    } for row in payload.get("data", [])]


def _moe_image(block: str) -> str:
    patterns = [
        r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)',
        r'<img[^>]+(?:data-src|src)=["\']([^"\']+)',
    ]
    for pattern in patterns:
        match = re.search(pattern, block, re.I)
        if match:
            return html.unescape(match.group(1)).replace("\\/", "/")
    return ""


def moewalls(query: str, page: int, browse_filter: str) -> list[dict]:
    # MoeWalls has no public API. Its searchable HTML is intentionally parsed
    # loosely so small theme/template changes do not break the provider.
    slug = urllib.parse.quote_plus(query.strip())
    if slug:
        url = f"https://moewalls.com/?s={slug}&paged={page}"
    elif browse_filter in {"anime", "games", "landscape", "sci-fi"}:
        suffix = f"page/{page}/" if page > 1 else ""
        url = f"https://moewalls.com/category/{browse_filter}/{suffix}"
    else:
        url = f"https://moewalls.com/page/{page}/" if page > 1 else "https://moewalls.com/"
    body = request(url).decode("utf-8", "replace")
    out: list[dict] = []
    articles = re.findall(r'<article\b.*?</article>', body, re.I | re.S)
    for article in articles:
        card = re.search(r'<a[^>]+title=["\']([^"\']+)["\'][^>]+href=["\'](https?://moewalls\.com/[^"\']+)["\']', article, re.I)
        image = re.search(r'<img[^>]+src=["\']([^"\']+)["\']', article, re.I)
        if not card or not image:
            continue
        title, link = html.unescape(card.group(1)), html.unescape(card.group(2))
        thumb = html.unescape(image.group(1))
        # WordPress exposes the original 1920px poster as the last srcset item.
        srcset = re.search(r'srcset=["\']([^"\']+)["\']', article, re.I)
        full = thumb
        if srcset:
            candidates = re.findall(r'(https?://\S+)\s+\d+w', html.unescape(srcset.group(1)))
            if candidates:
                full = candidates[-1]
        res = re.search(r'class=["\']entry-resolutions["\'].*?>(\d+x\d+)<', article, re.I | re.S)
        ident = re.sub(r'[^a-z0-9]+', '-', link.rstrip('/').split('/')[-1].lower()).strip('-')
        out.append({"id": ident or "moe-" + str(len(out)), "title": title, "thumb": thumb,
                    "preview": "", "full": full, "pageUrl": link,
                    "resolution": res.group(1) if res else "Live preview",
                    "source": "moewalls", "animated": True})
        if len(out) >= 30:
            break
    return cache_moe_thumbnails(out)


def download(url: str, source: str, ident: str) -> Path:
    payload, content_type, final_url = request_with_type(url)
    parsed = urllib.parse.urlparse(final_url or url)
    suffix = Path(parsed.path).suffix.lower()
    if suffix not in VIDEO_EXTS | IMAGE_EXTS:
        suffix = {
            "video/mp4": ".mp4",
            "video/webm": ".webm",
            "video/x-matroska": ".mkv",
            "image/jpeg": ".jpg",
            "image/png": ".png",
            "image/webp": ".webp",
        }.get(content_type, ".mp4" if source in {"motionbgs", "moewalls"} else ".jpg")

    # Keep exactly one persistent original. Caelestia stores this path as the
    # active wallpaper, so it must survive logout/reboot. A new selection removes
    # the old file first, preventing the selector from growing a wallpaper archive.
    folder = data_home() / "custom-wallpaper"
    folder.mkdir(parents=True, exist_ok=True)
    clean_id = re.sub(r"[^a-zA-Z0-9_-]", "-", ident)[:80]
    target = folder / f"{source}-{clean_id}{suffix}"

    # Preserve the currently active file until the selection is actually applied.
    active = None
    try:
        active = (Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local" / "state")))
                  / "caelestia" / "wallpaper" / "path.txt").read_text().strip()
    except OSError:
        pass

    for old in folder.iterdir():
        if old.is_file() and old != target and str(old) != active:
            old.unlink(missing_ok=True)
    target.write_bytes(payload)
    return target


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    search = sub.add_parser("search")
    search.add_argument("--source", choices=("wallhaven", "moewalls", "motionbgs", "local"), required=True)
    search.add_argument("--query", default="")
    search.add_argument("--page", type=int, default=1)
    search.add_argument("--purity", default="100")
    search.add_argument("--filter", default="latest")
    get = sub.add_parser("download")
    get.add_argument("--url", required=True)
    get.add_argument("--source", required=True)
    get.add_argument("--id", required=True)
    args = parser.parse_args()
    try:
        if args.command == "search":
            if args.source == "local":
                emit(local_wallpapers(args.query, args.filter))
            elif args.source == "motionbgs":
                emit(motionbgs(args.query, args.page, args.filter))
            elif args.source == "wallhaven":
                emit(wallhaven(args.query, args.page, args.purity, args.filter))
            else:
                emit(moewalls(args.query, args.page, args.filter))
        else:
            print(download(args.url, args.source, args.id))
        return 0
    except (OSError, urllib.error.URLError, json.JSONDecodeError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
