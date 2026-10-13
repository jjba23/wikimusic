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

/// A click track for a page a reader is practising from.
///
/// The sound is *made*, not fetched.  A click is twenty milliseconds of a
/// triangle wave with an envelope on it, built in the browser's own audio
/// graph, so a metronome costs a page no file, no network request and no
/// licence -- and an instance that reaches no CDN at run time still has one.
///
/// The clicks are scheduled ahead of the clock rather than fired by a timer.
/// A timer that fires every beat drifts by however late the browser runs it,
/// and a metronome that drifts is worse than none; so the beat times are
/// counted out in the audio clock's own seconds, a tenth of a second ahead of
/// the sound card, and the timer only ever asks for the next few of them.
///
/// The words are the page's, not this file's.  A page writes both labels its
/// control can show -- the metronome running and the metronome stopped -- and
/// this script un-hides one of them, so a translated page stays translated.
///
/// A page may hold more than one metronome, so everything below is reached by
/// the identifier the markup carries.  The identifiers are the only contract
/// between this file and the view that renders it:
///
///   <id>-tempo        the tempo, in beats per minute
///   <id>-beats        the beats in a bar
///   <id>-toggle       the control that starts and stops it
///   <id>-start        that control's label while it is stopped
///   <id>-stop         that control's label while it is running
///   <id>-beat-<n>     the lamps, one per beat the meter can hold
///   <id>-lamps        the row the lamps live in
///   <id>-widget       the whole control, hidden until this script finds it

const wikimusicMetronome = (() => {
  // How often the scheduler asks for more beats, and how far ahead of the
  // sound card it keeps them.  The lookahead is a compromise: long enough that
  // a late timer still has beats waiting, short enough that a tempo change is
  // heard within a beat of the reader making it.
  const lookaheadMilliseconds = 25;
  const lookaheadSeconds = 0.12;

  // The click itself: an accented first beat, a quiet one elsewhere.  The
  // frequencies are high enough to cut through a guitar and short enough not
  // to ring past the beat.
  const accentFrequency = 1600;
  const beatFrequency = 1000;
  const clickSeconds = 0.03;

  const defaultTempo = 120;
  const defaultBeats = 4;
  const slowestTempo = 20;
  const fastestTempo = 300;

  const running = new Map();

  const part = (id, suffix) => document.getElementById(id + suffix);

  const bounded = (value, lowest, highest, fallback) => {
    const number = Number.parseInt(value, 10);
    if (!Number.isFinite(number)) {
      return fallback;
    }
    return Math.min(Math.max(number, lowest), highest);
  };

  const tempoOf = (id) => {
    const field = part(id, "-tempo");
    return bounded(field && field.value, slowestTempo, fastestTempo, defaultTempo);
  };

  const beatsOf = (id) => {
    const field = part(id, "-beats");
    return bounded(field && field.value, 1, 6, defaultBeats);
  };

  const lampsOf = (id) => {
    const lamps = [];
    for (let beat = 1; beat <= 6; beat++) {
      const lamp = part(id, "-beat-" + beat);
      if (lamp) {
        lamps.push(lamp);
      }
    }
    return lamps;
  };

  // The lamps are the reader's own clock: the one that is lit is the beat that
  // is sounding.  A meter of three shows three of the six the page wrote.
  const showMeter = (id) => {
    const beats = beatsOf(id);
    lampsOf(id).forEach((lamp, index) => {
      lamp.hidden = index >= beats;
      lamp.classList.add("opacity-40");
    });
  };

  const lightBeat = (id, index) => {
    lampsOf(id).forEach((lamp, position) => {
      if (position === index) {
        lamp.classList.remove("opacity-40");
      } else {
        lamp.classList.add("opacity-40");
      }
    });
  };

  const click = (context, when, accent) => {
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    oscillator.type = "triangle";
    oscillator.frequency.value = accent ? accentFrequency : beatFrequency;
    gain.gain.setValueAtTime(0, when);
    gain.gain.linearRampToValueAtTime(accent ? 0.7 : 0.35, when + 0.002);
    gain.gain.exponentialRampToValueAtTime(0.0001, when + clickSeconds);
    oscillator.connect(gain);
    gain.connect(context.destination);
    oscillator.start(when);
    oscillator.stop(when + clickSeconds + 0.01);
  };

  const schedule = (id) => {
    const state = running.get(id);
    if (!state) {
      return;
    }
    const beats = beatsOf(id);
    // A tempo read afresh on every lookahead is what makes the tempo field
    // take effect while the metronome is running, which is what a reader
    // turning it down mid-practice expects.
    state.tempo = tempoOf(id);
    const secondsPerBeat = 60 / state.tempo;
    while (state.nextBeat < state.context.currentTime + lookaheadSeconds) {
      const index = state.beat % beats;
      click(state.context, state.nextBeat, index === 0);
      // The lamp is lit when the sound is *heard*, not when it is scheduled,
      // so it waits for the audio clock to reach the beat it belongs to.
      const delay = Math.max(0, (state.nextBeat - state.context.currentTime) * 1000);
      state.pending.push(setTimeout(() => lightBeat(id, index), delay));
      state.nextBeat += secondsPerBeat;
      state.beat += 1;
    }
  };

  const stopped = (id) => {
    const state = running.get(id);
    if (state) {
      clearInterval(state.timer);
      state.pending.forEach(clearTimeout);
      if (state.context.state !== "closed") {
        state.context.close();
      }
      running.delete(id);
    }
    showMeter(id);
    const button = part(id, "-toggle");
    const start = part(id, "-start");
    const stop = part(id, "-stop");
    if (start) {
      start.hidden = false;
    }
    if (stop) {
      stop.hidden = true;
    }
    if (button) {
      button.setAttribute("aria-pressed", "false");
    }
  };

  const start = (id) => {
    if (running.has(id)) {
      return;
    }
    const field = part(id, "-tempo");
    if (!field) {
      return;
    }
    const Sound = window.AudioContext || window.webkitAudioContext;
    if (!Sound) {
      return;
    }
    const context = new Sound();
    // A browser only lets a page make a sound after the reader has asked for
    // one, and pressing this control is exactly that; the context is created
    // here and nowhere else.
    context.resume();
    running.set(id, {
      context,
      timer: null,
      pending: [],
      nextBeat: context.currentTime + 0.08,
      beat: 0,
      tempo: tempoOf(id),
    });
    schedule(id);
    running.get(id).timer = setInterval(() => schedule(id), lookaheadMilliseconds);
    showMeter(id);
    const button = part(id, "-toggle");
    const start = part(id, "-start");
    const stop = part(id, "-stop");
    if (start) {
      start.hidden = true;
    }
    if (stop) {
      stop.hidden = false;
    }
    if (button) {
      button.setAttribute("aria-pressed", "true");
    }
  };

  const toggle = (id) => {
    if (running.has(id)) {
      stopped(id);
    } else {
      start(id);
    }
  };

  // A meter changed while the metronome runs is heard on the next beat, and
  // the lamps follow it straight away.
  const meterChanged = (id) => {
    const state = running.get(id);
    if (state) {
      state.beat = 0;
    }
    showMeter(id);
  };

  const ready = () => {
    const widgets = document.querySelectorAll("[data-metronome]");
    Array.prototype.forEach.call(widgets, (widget) => {
      widget.hidden = false;
      showMeter(widget.id);
    });
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", ready);
  } else {
    ready();
  }

  return { toggle, meterChanged, start, stop };
})();

// The markup reaches these by name, the way the rest of the site's controls
// reach their own handlers.
function wikimusicMetronomeToggle(id) {
  wikimusicMetronome.toggle(id);
}

function wikimusicMetronomeMeterChanged(id) {
  wikimusicMetronome.meterChanged(id);
}
