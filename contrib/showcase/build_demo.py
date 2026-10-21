#!/usr/bin/env python3
"""Build the isolated WikiMusic instance the showcase GIF is recorded from.

The recording must never show a broken picture, and it should not depend on
the network while the camera is running.  This script therefore:

  1. copies the project's SQLite database into a throw-away directory,
  2. resolves the song, artist and genre the showcase walks through,
  3. downloads every artwork they and the rest of the copy refer to, converts
     the pictures to ordinary JPEGs, and points the copy's rows at local
     files under ``pub/img/demo/``,
  4. drops any artwork row whose picture cannot be fetched, so a tile is
     drawn without a picture instead of with a broken one, and
  5. writes ``showcase.json``, which tells the recorder which pages to visit.

Downloads are cached under ``$XDG_CACHE_HOME/wikimusic-showcase/artwork`` and
keyed by URL, so a second run is fast and can be made fully offline with
``--offline``.

The project's own database and ``pub/img`` are never modified: the demo
instance is the repository with symlinks for everything but its database,
its ``pub/img`` and its ``conf/``.
"""

from __future__ import annotations

import argparse
import concurrent.futures as futures
import hashlib
import io
import json
import os
import re
import shutil
import sqlite3
import sys
import time
import urllib.parse
from pathlib import Path

import requests
from PIL import Image

UA = ("WikiMusic-showcase/1.0 "
      "(+https://wikimusic.jointhefreeworld.org; jjbigorra@gmail.com)")

# Where the stored picture is dead (a host that no longer resolves, or a link
# that answers 400/403), the same picture still lives on Wikipedia.  Keeping
# the featured pages' artwork is worth naming the substitutes explicitly.
REPLACEMENTS = {
    "https://assets.wikimusic.jointhefreeworld.org/artists/death/leprosy.jpg":
        "https://upload.wikimedia.org/wikipedia/en/1/14/Leprosy_Album.jpg",
    "https://assets.wikimusic.jointhefreeworld.org/MTMtMTk1MC5qcGVn.jpeg":
        "https://upload.wikimedia.org/wikipedia/en/8/83/Messageinabottle.jpg",
}

ARTWORK_TABLES = ("song_artworks", "artist_artworks", "genre_artworks")


def decode(url: str) -> str:
    """Undo the (possibly repeated) URL-encoding some rows were stored with."""
    for _ in range(4):
        new = urllib.parse.unquote(url)
        if new == url:
            break
        url = new
    return url


def cache_dir() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    return Path(base) / "wikimusic-showcase" / "artwork"


class ArtworkCache:
    """A URL-keyed cache of picture bytes, with a small JSON index."""

    def __init__(self, directory: Path):
        self.directory = directory
        self.directory.mkdir(parents=True, exist_ok=True)
        self.index_path = directory / "index.json"
        try:
            self.index = json.loads(self.index_path.read_text())
        except (OSError, ValueError):
            self.index = {}

    def get(self, url: str):
        entry = self.index.get(url)
        if not entry:
            return None
        path = self.directory / entry["file"]
        if not path.exists():
            return None
        return path.read_bytes(), entry["ext"]

    def put(self, url: str, data: bytes, ext: str):
        name = hashlib.sha256(url.encode()).hexdigest()[:16] + "." + ext
        (self.directory / name).write_bytes(data)
        self.index[url] = {"file": name, "ext": ext}
        tmp = self.index_path.with_suffix(".tmp")
        tmp.write_text(json.dumps(self.index, indent=1, sort_keys=True))
        os.replace(tmp, self.index_path)


def fetch(url: str, cache: ArtworkCache, offline: bool):
    """Return (bytes, extension) for a raster or SVG picture, or None."""
    cached = cache.get(url)
    if cached:
        return cached
    if offline:
        return None

    effective = REPLACEMENTS.get(url, url)
    headers = {"User-Agent": UA,
               "Accept": "image/avif,image/webp,image/*,*/*;q=0.8"}
    for attempt in range(3):
        try:
            response = requests.get(decode(effective), headers=headers,
                                    timeout=25, allow_redirects=True)
            if response.status_code != 200:
                return None
            content_type = response.headers.get("content-type", "")
            data = response.content
            if "svg" in content_type or data.lstrip()[:5] in (b"<?xml", b"<svg "):
                cache.put(url, data, "svg")
                return data, "svg"
            if not data:
                return None
            image = Image.open(io.BytesIO(data))
            image.load()
            if image.mode in ("RGBA", "LA", "P"):
                image = image.convert("RGBA")
                background = Image.new("RGB", image.size, (255, 255, 255))
                background.paste(image, mask=image.split()[-1])
                image = background
            else:
                image = image.convert("RGB")
            # Covers stay sharp at the recording's 1440px width without
            # carrying enormous originals into the demo instance.
            image.thumbnail((1200, 1200), Image.LANCZOS)
            out = io.BytesIO()
            image.save(out, "JPEG", quality=88, optimize=True, progressive=True)
            data = out.getvalue()
            cache.put(url, data, "jpg")
            return data, "jpg"
        except Exception:
            time.sleep(0.6 * (attempt + 1))
    return None


def single(conn, query, args=()):
    return conn.execute(query, args).fetchone()


def require_entity(kind: str, name: str, checks):
    """Fail with an actionable message when the demo cannot show `name`."""
    for label, ok, hint in checks:
        if not ok:
            raise SystemExit(
                f"showcase {kind} {name!r} has no {label}; pick another one "
                f"with --{kind} or seed it first ({hint})")


def resolve_showcase(conn, song_name: str, artist_name: str, genre_name: str,
                     search: str | None):
    """Find the pages the recording walks, and check they show their features."""
    song = single(conn,
                  "select identifier, display_name, description from songs "
                  "where display_name = ? order by views desc limit 1",
                  (song_name,))
    if not song:
        raise SystemExit(f"no song named {song_name!r} in the database; "
                         "pass --song or seed the database first")
    song_id, song_display, description = song

    artist = single(conn,
                    "select a.identifier, a.display_name, a.description "
                    "from song_artists sa join artists a "
                    "on a.identifier = sa.artist_identifier "
                    "where sa.song_identifier = ? limit 1", (song_id,))
    if not artist:
        raise SystemExit(f"song {song_name!r} has no artist")

    genre = single(conn,
                   "select g.identifier, g.display_name, g.description "
                   "from song_genres sg join genres g "
                   "on g.identifier = sg.genre_identifier "
                   "where sg.song_identifier = ? limit 1", (song_id,))
    if not genre:
        raise SystemExit(f"song {song_name!r} has no genre")

    artist_id, artist_display, artist_description = artist
    genre_id, genre_display, genre_description = genre

    tab = single(conn,
                 "select count(*) from song_contents where song_identifier = ? "
                 "and visibility_status = 0 "
                 "and length(coalesce(ascii_contents, '')) > 0", (song_id,))[0]
    counts = {}
    for table, column, identifier in (
            ("song_artworks", "song_identifier", song_id),
            ("artist_artworks", "artist_identifier", artist_id),
            ("genre_artworks", "genre_identifier", genre_id)):
        counts[column] = single(conn, f"select count(*) from {table} "
                                      f"where {column} = ?", (identifier,))[0]

    require_entity("song", song_display, [
        ("description", bool((description or "").strip()),
         "a song page without prose is not the happy path"),
        ("tablature", tab > 0, "upload a Guitar Pro file for it"),
        ("artwork", counts["song_identifier"] > 0,
         "attach a picture to it"),
    ])
    require_entity("artist", artist_display, [
        ("description", bool((artist_description or "").strip()),
         "a blank artist page is not the happy path"),
        ("artwork", counts["artist_identifier"] > 0,
         "attach a picture to it"),
    ])
    require_entity("genre", genre_display, [
        ("description", bool((genre_description or "").strip()),
         "a blank genre page is not the happy path"),
        ("artwork", counts["genre_identifier"] > 0,
         "attach a picture to it"),
    ])

    if not search:
        words = [w for w in re.split(r"\s+", song_display) if len(w) > 2]
        search = (words[-1] if words else song_display).lower()
        if not search:
            raise SystemExit("could not derive a search term; pass --search")

    return {
        "song": {"name": song_display, "path": f"/songs/uuid/{song_id}"},
        "artist": {"name": artist_display,
                   "path": f"/artists/uuid/{artist_id}"},
        "genre": {"name": genre_display, "path": f"/genres/uuid/{genre_id}"},
        "search": search,
    }


def ensure_featured_artwork(conn, showcase):
    """Refuse a demo whose featured pages lost their pictures.

    Online, unreachable pictures are dropped; a featured page without one is
    still a working page, but it is not the showcase the README promises.
    """
    for kind, table, column in (
            ("song", "song_artworks", "song_identifier"),
            ("artist", "artist_artworks", "artist_identifier"),
            ("genre", "genre_artworks", "genre_identifier")):
        identifier = showcase[kind]["path"].rsplit("/", 1)[-1]
        count = single(conn, f"select count(*) from {table} "
                             f"where {column} = ?", (identifier,))[0]
        if not count:
            raise SystemExit(
                f"the featured {kind} {showcase[kind]['name']!r} has no "
                "artwork left; fetch the pictures once without --offline "
                "or pick another page")


def copy_project(repo: Path, demo: Path, port: int):
    """Lay the repository out around the demo's own database and pictures."""
    demo.mkdir(parents=True, exist_ok=True)
    for name in ("app", "lib", "sys", "resources", "ENTRY", "env.scm",
                 "manifest.scm", "channels.scm", "log", "test"):
        target = repo / name
        if target.exists():
            os.symlink(target, demo / name)
    (demo / "pub").mkdir(parents=True, exist_ok=True)
    for name in ("css", "js", "vendor", "favicon.ico"):
        target = repo / "pub" / name
        if target.exists():
            os.symlink(target, demo / "pub" / name)
    upload = repo / "pub" / "img" / "upload"
    if upload.exists():
        os.symlink(upload, demo / "pub" / "img" / "upload")

    (demo / "conf").mkdir(parents=True, exist_ok=True)
    shutil.copy(repo / "conf" / "plugins.scm", demo / "conf" / "plugins.scm")
    text = (repo / "conf" / "artanis.conf").read_text()
    text = re.sub(r"^host\.port = .*$", f"host.port = {port}", text,
                  flags=re.M)
    (demo / "conf" / "artanis.conf").write_text(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    default_repo = Path(__file__).resolve().parents[2]
    parser.add_argument("--repo", type=Path, default=default_repo,
                        help="the WikiMusic checkout (default: this one)")
    parser.add_argument("--demo", type=Path,
                        default=Path(os.environ.get(
                            "WIKIMUSIC_SHOWCASE_DEMO",
                            "/tmp/wikimusic-showcase-demo")),
                        help="where to build the throw-away instance")
    parser.add_argument("--port", type=int, default=50051,
                        help="port the demo instance listens on")
    parser.add_argument("--song", default="Left to Die",
                        help="the song the recording opens")
    parser.add_argument("--artist", default="Death",
                        help="the artist the recording opens")
    parser.add_argument("--genre", default="Death Metal",
                        help="the genre the recording opens")
    parser.add_argument("--search", default=None,
                        help="the term typed into the search field "
                             "(default: the last word of the song's title)")
    parser.add_argument("--offline", action="store_true",
                        help="use only cached artwork; never touch the network")
    args = parser.parse_args()

    repo, demo = args.repo.resolve(), args.demo.resolve()
    db_source = repo / "wikimusic.db"
    if not db_source.exists():
        raise SystemExit(f"{db_source} does not exist; run `maak init-db` "
                         "and seed the instance first")
    if demo == repo or repo in demo.parents:
        raise SystemExit("the demo directory must be outside the checkout, "
                         "since it is deleted and rebuilt on every run")

    if demo.exists():
        shutil.rmtree(demo)
    images = demo / "pub" / "img" / "demo"
    images.mkdir(parents=True)

    # Copy through SQLite's backup API so a running server's WAL comes along.
    source = sqlite3.connect(db_source)
    target = sqlite3.connect(demo / "wikimusic.db")
    source.backup(target)
    source.close()

    showcase = resolve_showcase(target, args.song, args.artist, args.genre,
                                args.search)

    cache = ArtworkCache(cache_dir())
    urls = set()
    for table in ARTWORK_TABLES:
        for (url,) in target.execute(f"select content_url from {table}"):
            if url:
                # Several rows were stored URL-encoded (sometimes twice); the
                # decoded URL is what the browser would request and what the
                # cache is keyed by.
                urls.add(decode(url))
    urls = sorted(urls)
    print(f"{len(urls)} distinct artwork URLs", flush=True)

    results = {}
    if args.offline:
        for url in urls:
            results[url] = cache.get(url)
        # A miss is not fatal: the online run drops unreachable pictures too,
        # and the featured pages are checked for artwork again below.  It is
        # worth saying out loud, though, because an empty cache would quietly
        # turn the showcase into a picture-less one.
        missing = [u for u, got in results.items() if not got]
        if missing:
            print(f"warning: {len(missing)} picture(s) are not in the cache "
                  "and will be dropped (run once without --offline to fetch "
                  "whatever is reachable)", file=sys.stderr)
    else:
        with futures.ThreadPoolExecutor(max_workers=8) as pool:
            pending = {pool.submit(fetch, url, cache, False): url for url in urls}
            for done, future in enumerate(futures.as_completed(pending), 1):
                url = pending[future]
                try:
                    results[url] = future.result()
                except Exception:
                    results[url] = None
                if done % 25 == 0:
                    print(f"  {done}/{len(urls)}", flush=True)

        # Wikimedia rate-limits a burst; its budget comes back within a minute.
        for _ in range(2):
            retry = [u for u, got in results.items() if got is None]
            if not retry:
                break
            print(f"retrying {len(retry)} picture(s) slowly...", flush=True)
            for url in retry:
                time.sleep(2.5)
                results[url] = fetch(url, cache, False)

    by_url = {}
    failed = []
    for url, got in results.items():
        if not got:
            failed.append(url)
            continue
        data, ext = got
        name = hashlib.sha256(url.encode()).hexdigest()[:16] + "." + ext
        (images / name).write_bytes(data)
        by_url[url] = "/img/demo/" + name

    removed = 0
    for table in ARTWORK_TABLES:
        rows = list(target.execute(f"select identifier, content_url from {table}"))
        for identifier, url in rows:
            decoded = decode(url) if url else url
            if decoded in by_url:
                target.execute(f"update {table} set content_url = ? "
                               f"where identifier = ?",
                               (by_url[decoded], identifier))
            else:
                target.execute(f"delete from {table} where identifier = ?",
                               (identifier,))
                removed += 1
    ensure_featured_artwork(target, showcase)
    target.commit()
    target.close()

    print(f"cached {len(by_url)} picture(s), dropped {removed} broken row(s)")
    if failed:
        print("unreachable (dropped from the demo instance):")
        for url in failed:
            print("  " + url[:160])

    copy_project(repo, demo, args.port)

    showcase["base"] = f"http://localhost:{args.port}"
    (demo / "showcase.json").write_text(json.dumps(showcase, indent=2) + "\n")
    print(f"demo instance ready at {demo}")
    print(f"  {showcase['song']['name']}  {showcase['song']['path']}")
    print(f"  {showcase['artist']['name']}  {showcase['artist']['path']}")
    print(f"  {showcase['genre']['name']}  {showcase['genre']['path']}")


if __name__ == "__main__":
    main()
