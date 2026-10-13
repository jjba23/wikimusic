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
        boundPassageFields(id, api);
        setLoopLabel(id, false);
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

  /// How fast the tab is played back, as a fraction of the tempo it is written
  /// in.  A passage a reader cannot play at speed is practised slowly and
  /// speeded up afterwards, so this is the control that makes a stored tab a
  /// thing to learn from rather than a thing to listen to.
  const speed = (id, value) => {
    const api = players.get(id);
    const multiplier = Number.parseFloat(value);
    if (api && Number.isFinite(multiplier) && multiplier > 0) {
      api.playbackSpeed = multiplier;
    }
  };

  // The number a reader typed into one of the passage fields, or a fallback.
  const barNumber = (id, suffix, fallback) => {
    const field = part(id, suffix);
    const number = field ? Number.parseInt(field.value, 10) : Number.NaN;
    return Number.isFinite(number) ? number : fallback;
  };

  // The ticks a passage of bars covers.  A master bar carries the tick it
  // starts at and can say how long it is, so the passage is measured out of
  // the score itself rather than guessed at from its tempo: a bar of five-four
  // and a bar of four-four are not the same number of ticks, and an anacrusis
  // and a repeat are not either.
  const passageTicks = (api, first, last) => {
    const bars = (api.score && api.score.masterBars) || [];
    if (bars.length === 0) {
      return null;
    }
    const from = Math.min(Math.max(first, 1), bars.length);
    const to = Math.min(Math.max(last, from), bars.length);
    const firstBar = bars[from - 1];
    const lastBar = bars[to - 1];
    const endTick = lastBar.start + lastBar.calculateDuration();
    if (!Number.isFinite(firstBar.start) || !Number.isFinite(endTick)) {
      return null;
    }
    return { startTick: firstBar.start, endTick: endTick };
  };

  // Whether a passage is armed, and which of the button's two labels says so.
  // Both labels are the page's own words, written into the markup; this only
  // decides which of them is shown, so a translated page stays translated.
  const setLoopLabel = (id, armed) => {
    const on = part(id, "-loop-idle");
    const off = part(id, "-loop-armed");
    const button = part(id, "-loop");
    if (on) {
      on.hidden = armed;
    }
    if (off) {
      off.hidden = !armed;
    }
    if (button) {
      button.setAttribute("aria-pressed", armed ? "true" : "false");
    }
  };

  /// Arm the passage between the two bar fields, or disarm it when one is
  /// already armed.  A reader drills a few bars by playing them over and over,
  /// which is what the loop does; a bar of count-in is played first while a
  /// passage is armed, so the reader hears where the passage begins instead of
  /// having to guess from a click that stops at the end.
  const toggleLoop = (id) => {
    const api = players.get(id);
    if (!api) {
      return;
    }
    if (api.playbackRange) {
      api.isLooping = false;
      api.playbackRange = null;
      api.countInVolume = 0;
      setLoopLabel(id, false);
      return;
    }
    const ticks = passageTicks(api,
                               barNumber(id, "-loop-from", 1),
                               barNumber(id, "-loop-to", 1));
    if (!ticks) {
      return;
    }
    api.countInVolume = 0.9;
    api.playbackRange = ticks;
    api.isLooping = true;
    api.tickPosition = ticks.startTick;
    setLoopLabel(id, true);
  };

  // A passage cannot name a bar the tablature does not have, so once the score
  // is drawn the fields are given the length of the score as their ceiling and
  // a value that is inside it.
  const boundPassageFields = (id, api) => {
    const bars = (api.score && api.score.masterBars) || [];
    if (bars.length === 0) {
      return;
    }
    ["-loop-from", "-loop-to"].forEach((suffix) => {
      const field = part(id, suffix);
      if (!field) {
        return;
      }
      field.max = String(bars.length);
      const value = Number.parseInt(field.value, 10);
      if (!Number.isFinite(value) || value < 1) {
        field.value = "1";
      } else if (value > bars.length) {
        field.value = String(bars.length);
      }
    });
  };

  return { show, playPause, stop, speed, toggleLoop };
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

function wikimusicGuitarProSpeed(id, value) {
  wikimusicGuitarPro.speed(id, value);
}

function wikimusicGuitarProToggleLoop(id) {
  wikimusicGuitarPro.toggleLoop(id);
}
