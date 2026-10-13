/// wikimusic - the free music knowledge encyclopaedia

// Copyright © Josep Bigorra <jjbigorra@gmail.com>

// wikimusic is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// wikimusic is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with wikimusic.  If not, see <https://www.gnu.org/licenses/>.

/// Drawing and playing back a stored Guitar Pro tab.
///
/// The renderer is a megabyte of JavaScript and the SoundFont that makes a tab
/// audible is a megabyte more, and a reader who opened a song page is not
/// necessarily there for its tablature.  So neither is fetched until a reader
/// asks to see a tab, and a page whose tabs are never opened costs a reader
/// nothing but this file.
///
/// The words are not written here.  A page that offers a tab carries its own
/// sentences -- one for each state the player can be in -- and this script
/// only decides which of them is shown, so a translated page stays translated
/// when the tablature loads.
///
/// A page may hold several versions, each with its own tab, so every entry
/// point below takes the identifier the section carries in the markup and
/// looks the rest up from it.  The identifiers are the only contract between
/// this file and the view that renders it.

const wikimusicGuitarPro = (() => {
  // Where the vendored release lives.  These are paths and not URLs: they are
  // resolved against the page, so an instance served under a prefix serves its
  // own files without being told it is.
  const base = "/vendor/alphatab/";
  const script = "alphaTab.min.js";
  const fontDirectory = "font/";
  const soundFont = "soundfont/sonivox.sf2";

  const absolute = (name) => new URL(name, new URL(base, document.baseURI)).href;

  // One promise for the renderer, however many tabs the page holds: the second
  // reader to ask for a tab waits on the first reader's download rather than
  // starting their own.
  let renderer = null;

  const loadRenderer = () => {
    if (renderer) {
      return renderer;
    }
    renderer = new Promise((resolve, reject) => {
      if (window.alphaTab) {
        resolve(window.alphaTab);
        return;
      }
      const element = document.createElement("script");
      element.src = absolute(script);
      element.onload = () => resolve(window.alphaTab);
      element.onerror = () => reject(new Error("alphaTab could not be loaded"));
      document.head.appendChild(element);
    });
    return renderer;
  };

  // The file is in the page as the data URL a file input made of it, which is
  // also what the download link hands a reader.  It is read from there rather
  // than written into the page a second time: a tab is the largest thing a
  // version carries, and a page that holds several of them should hold each
  // one once.
  const fileBytes = (dataUrl) => {
    const comma = dataUrl.indexOf(",");
    const payload = dataUrl.slice(comma + 1);
    if (dataUrl.slice(0, comma).includes(";base64")) {
      const binary = atob(payload);
      const bytes = new Uint8Array(binary.length);
      for (let index = 0; index < binary.length; index++) {
        bytes[index] = binary.charCodeAt(index);
      }
      return bytes;
    }
    return new TextEncoder().encode(decodeURIComponent(payload));
  };

  const part = (id, suffix) => document.getElementById(id + suffix);

  const setStatus = (id, state) => {
    ["loading", "ready", "failed"].forEach((one) => {
      const element = part(id, "-status-" + one);
      if (element) {
        element.hidden = one !== state;
      }
    });
  };

  const players = new Map();

  const show = async (id) => {
    if (players.has(id)) {
      return;
    }
    const section = document.getElementById(id);
    const host = part(id, "-score");
    const file = part(id, "-file");
    const controls = part(id, "-controls");
    const ask = part(id, "-ask");
    if (!section || !host || !file) {
      return;
    }
    if (ask) {
      ask.hidden = true;
    }
    setStatus(id, "loading");
    try {
      const [alphaTab, bytes] = await Promise.all([
        loadRenderer(),
        Promise.resolve(fileBytes(file.getAttribute("href"))),
      ]);
      const api = new alphaTab.AlphaTabApi(host, {
        core: {
          // The worker a score is rendered in is loaded by alphaTab itself,
          // through a blob that can only name an absolute URL, so the file is
          // named here rather than left to be guessed from the page.
          scriptFile: absolute(script),
          fontDirectory: absolute(fontDirectory),
        },
        player: {
          enablePlayer: true,
          soundFont: absolute(soundFont),
        },
      });
      players.set(id, api);
      api.scoreLoaded.on(() => {
        // The tablature is drawn; the controls appear with it.  Pressing play
        // is what a reader does next, and their press is what lets the browser
        // start an audio context, so playback is not waited for here.
        if (controls) {
          controls.hidden = false;
        }
      });
      api.playerReady.on(() => setStatus(id, "ready"));
      api.error.on(() => {
        setStatus(id, "failed");
        if (ask) {
          ask.hidden = false;
        }
      });
      api.load(bytes);
    } catch (error) {
      setStatus(id, "failed");
      if (ask) {
        ask.hidden = false;
      }
    }
  };

  const playPause = (id) => {
    const api = players.get(id);
    if (api) {
      api.playPause();
    }
  };

  const stop = (id) => {
    const api = players.get(id);
    if (api) {
      api.stop();
    }
  };

  return { show, playPause, stop };
})();

// The markup reaches these by name, the way the rest of the site's controls
// reach their own handlers.
function wikimusicGuitarProShow(id) {
  wikimusicGuitarPro.show(id);
}

function wikimusicGuitarProPlayPause(id) {
  wikimusicGuitarPro.playPause(id);
}

function wikimusicGuitarProStop(id) {
  wikimusicGuitarPro.stop(id);
}
