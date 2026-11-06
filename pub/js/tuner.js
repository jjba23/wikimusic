/* wikimusic - the free music knowledge encyclopaedia
 *
 * SPDX-License-Identifier: MIT
 * Copyright © Josep Bigorra <jjbigorra@gmail.com>
*/

/// A tuner that listens rather than a tuner that guesses.
///
/// The microphone is read here, in the browser, and the sound never leaves it:
/// nothing is recorded, nothing is uploaded, and the page is idle until a
/// reader presses the control.  A pitch is found by autocorrelation -- how much
/// the signal looks like a delayed copy of itself -- which is what makes a
/// guitar string's fundamental readable even though its loudest partials are
/// higher than it is.
///
/// The words are the page's, not this file's.  Every sentence a reader can meet
/// is written by the view and this script only un-hides one of them, so a
/// translated page stays translated while the tuner listens, and when it cannot
/// listen at all.
///
/// A page holds one tuner, and everything below is reached by the identifier the
/// markup gives it:
///
///   <id>                  the whole control, hidden until this script is here
///   <id>-note             the note that is sounding
///   <id>-cents            how far it is from that note, in cents
///   <id>-needle           the marker on the meter (-50 .. +50 cents)
///   <id>-status-idle      before a note is heard
///   <id>-status-listening a note is being waited for
///   <id>-status-in-tune   close enough to be in tune
///   <id>-status-denied    the microphone was refused, or there is none
///   <id>-status-unsupported  a browser that cannot read a microphone
///   <id>-toggle           the control that starts and stops it
///   <id>-start            that control's label while it is stopped
///   <id>-stop             that control's label while it is running
///   data-midi             on a string of the preset: the note it is tuned to

const wikimusicTuner = (() => {
  // Within this many cents a string is in tune.  Five is what a mechanical
  // tuner calls in tune, and a hand that is closer than that is wasting its
  // time on a guitar whose frets are not that exact.
  const inTuneCents = 5;

  // What a pitch can be, in hertz.  A five-string bass's low B is 30.87 and the
  // highest note a guitar plays is around 1300; the range is wider than either
  // so that a note outside it is ignored rather than reported as its octave.
  const lowestHertz = 55;
  const highestHertz = 1400;

  // How often the microphone is read, and how many readings a note has to
  // survive.  A median of the last few: a single misread frame must not move
  // the needle, and a note that really changed must not take a second to say so.
  const readEveryMilliseconds = 60;
  const readingsKept = 5;

  // The string a reader is closest to is lit within this many cents, so the
  // page answers "which one am I tuning" as well as "is it right".
  const nearestStringCents = 250;

  const running = new Map();
  let toneContext = null;

  const part = (id, suffix) => document.getElementById(id + suffix);
  const frequencyOf = (midi) => 440 * Math.pow(2, (midi - 69) / 12);
  const centsBetween = (heard, target) => 1200 * Math.log2(heard / target);

  const showStatus = (id, suffix) => {
    [
      "-status-idle",
      "-status-listening",
      "-status-in-tune",
      "-status-denied",
      "-status-unsupported",
    ].forEach((name) => {
      const span = part(id, name);
      if (span) {
        span.hidden = name !== suffix;
      }
    });
  };

  const showLabels = (id, listening) => {
    const start = part(id, "-start");
    const stop = part(id, "-stop");
    const button = part(id, "-toggle");
    if (start) {
      start.hidden = listening;
    }
    if (stop) {
      stop.hidden = !listening;
    }
    if (button) {
      button.setAttribute("aria-pressed", listening ? "true" : "false");
    }
  };

  // The strings of the preset the page was read at, as the notes they should
  // sound at.  They are the page's, so changing the preset is changing the
  // address rather than telling this script about it.
  const stringsOf = (widget) =>
    Array.prototype.map.call(
      widget.querySelectorAll("[data-midi]"),
      (element) => ({
        midi: Number.parseInt(element.getAttribute("data-midi"), 10),
        element,
      }),
    );

  const markString = (id, midi) => {
    const widget = document.getElementById(id);
    if (!widget) {
      return;
    }
    Array.prototype.forEach.call(widget.querySelectorAll("[data-midi]"), (element) => {
      const isIt =
        midi !== null &&
        Number.parseInt(element.getAttribute("data-midi"), 10) === midi;
      if (isIt) {
        element.setAttribute("data-active", "true");
      } else {
        element.removeAttribute("data-active");
      }
    });
  };

  // The pitch of a buffer of samples, or 0 when it holds no note.
  //
  // The samples are correlated with themselves at every delay a note could have,
  // and the first delay that is nearly as strong as the strongest one wins: that
  // is the fundamental, where a later peak would be a harmonic of it.  The peak
  // is then read between samples, which is what turns a delay of 73.4 samples
  // into a frequency instead of rounding it to 73.
  const detect = (data, sampleRate) => {
    let energy = 0;
    for (let index = 0; index < data.length; index++) {
      energy += data[index] * data[index];
    }
    if (Math.sqrt(energy / data.length) < 0.008) {
      return 0;
    }

    const firstLag = Math.max(2, Math.floor(sampleRate / highestHertz));
    const lastLag = Math.min(
      Math.floor(sampleRate / lowestHertz),
      Math.floor(data.length / 2),
    );
    const window = Math.floor(data.length / 2) - 1;
    const scores = new Float32Array(lastLag + 2);
    let strongest = 0;

    for (let lag = firstLag; lag <= lastLag; lag++) {
      let sum = 0;
      for (let index = 0; index < window; index++) {
        sum += data[index] * data[index + lag];
      }
      scores[lag] = sum / window;
      if (scores[lag] > strongest) {
        strongest = scores[lag];
      }
    }
    if (strongest <= 0) {
      return 0;
    }

    const enough = strongest * 0.9;
    let best = -1;
    for (let lag = firstLag + 1; lag < lastLag; lag++) {
      if (
        scores[lag] >= enough &&
        scores[lag] > scores[lag - 1] &&
        scores[lag] >= scores[lag + 1]
      ) {
        best = lag;
        break;
      }
    }
    if (best < 0) {
      return 0;
    }

    const before = scores[best - 1];
    const at = scores[best];
    const after = scores[best + 1];
    const bend = (before - after) / (2 * (before - 2 * at + after));
    const lag = best + (Number.isFinite(bend) ? bend : 0);
    return lag > 0 ? sampleRate / lag : 0;
  };

  const median = (values) => {
    const sorted = values.slice().sort((left, right) => left - right);
    return sorted[Math.floor(sorted.length / 2)];
  };

  const report = (id) => {
    const current = running.get(id);
    if (!current) {
      return;
    }

    const note = part(id, "-note");
    const cents = part(id, "-cents");
    const needle = part(id, "-needle");
    const widget = document.getElementById(id);
    const heard = current.heard;

    if (!heard) {
      if (note) {
        note.textContent = "—";
      }
      if (cents) {
        cents.textContent = "";
      }
      if (needle) {
        needle.style.setProperty("--wm-cents", "0");
      }
      if (widget) {
        widget.removeAttribute("data-in-tune");
      }
      markString(id, null);
      showStatus(id, "-status-listening");
      return;
    }

    const nearest = Math.round(69 + 12 * Math.log2(heard / 440));
    const off = centsBetween(heard, frequencyOf(nearest));
    const rounded = Math.abs(off) < 1 ? 0 : Math.round(off);

    if (note) {
      note.textContent = current.nameOf(nearest);
    }
    if (cents) {
      cents.textContent = (rounded > 0 ? "+" : rounded < 0 ? "−" : "") + Math.abs(rounded);
    }
    if (needle) {
      needle.style.setProperty(
        "--wm-cents",
        String(Math.max(-50, Math.min(50, off))),
      );
    }

    let closest = null;
    current.strings.forEach((string) => {
      const distance = Math.abs(centsBetween(heard, frequencyOf(string.midi)));
      if (!closest || distance < closest.distance) {
        closest = { midi: string.midi, distance };
      }
    });
    markString(
      id,
      closest && closest.distance < nearestStringCents ? closest.midi : null,
    );

    const inTune = Math.abs(off) <= inTuneCents;
    if (widget) {
      if (inTune) {
        widget.setAttribute("data-in-tune", "true");
      } else {
        widget.removeAttribute("data-in-tune");
      }
    }
    showStatus(id, inTune ? "-status-in-tune" : "-status-listening");
  };

  const analyse = (id) => {
    const current = running.get(id);
    if (!current) {
      return;
    }
    current.analyser.getFloatTimeDomainData(current.buffer);
    const heard = detect(current.buffer, current.context.sampleRate);
    current.readings.push(heard);
    if (current.readings.length > readingsKept) {
      current.readings.shift();
    }
    const sounding = current.readings.filter((reading) => reading > 0);
    current.heard = sounding.length
      ? sounding.length === current.readings.length
        ? median(sounding)
        : sounding[sounding.length - 1]
      : 0;
    report(id);
  };

  const stop = (id) => {
    const current = running.get(id);
    if (current) {
      clearInterval(current.timer);
      try {
        current.source.disconnect();
      } catch (error) {}
      current.stream.getTracks().forEach((track) => track.stop());
      if (current.context.state !== "closed") {
        current.context.close();
      }
      running.delete(id);
    }
    const note = part(id, "-note");
    const cents = part(id, "-cents");
    const needle = part(id, "-needle");
    const widget = document.getElementById(id);
    if (note) {
      note.textContent = "—";
    }
    if (cents) {
      cents.textContent = "";
    }
    if (needle) {
      needle.style.setProperty("--wm-cents", "0");
    }
    if (widget) {
      widget.removeAttribute("data-in-tune");
      widget.setAttribute("data-listening", "false");
    }
    markString(id, null);
    showLabels(id, false);
    showStatus(id, "-status-idle");
  };

  const start = async (id) => {
    if (running.has(id)) {
      return;
    }
    const widget = document.getElementById(id);
    const Sound = window.AudioContext || window.webkitAudioContext;
    if (
      !widget ||
      !Sound ||
      !navigator.mediaDevices ||
      !navigator.mediaDevices.getUserMedia
    ) {
      showStatus(id, "-status-unsupported");
      showLabels(id, false);
      return;
    }

    let stream;
    try {
      // A tuner wants the string, not the room: the processing a browser does
      // for a call would gate a decaying note away and hide its pitch.
      stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: false,
          noiseSuppression: false,
          autoGainControl: false,
        },
        video: false,
      });
    } catch (error) {
      showStatus(id, "-status-denied");
      showLabels(id, false);
      return;
    }

    const context = new Sound();
    context.resume();
    const analyser = context.createAnalyser();
    analyser.fftSize = 2048;
    analyser.smoothingTimeConstant = 0;
    const source = context.createMediaStreamSource(stream);
    // Read, never played back: a page that sent the room to its own speakers
    // would howl, and a tuner is listened to with an instrument sounding.
    source.connect(analyser);

    running.set(id, {
      context,
      stream,
      source,
      analyser,
      buffer: new Float32Array(analyser.fftSize),
      readings: [],
      heard: 0,
      strings: stringsOf(widget),
      nameOf: (midi) => {
        const names = [
          "C",
          "C#",
          "D",
          "D#",
          "E",
          "F",
          "F#",
          "G",
          "G#",
          "A",
          "A#",
          "B",
        ];
        return names[((midi % 12) + 12) % 12] + (Math.floor(midi / 12) - 1);
      },
      timer: null,
    });
    running.get(id).timer = setInterval(() => analyse(id), readEveryMilliseconds);
    widget.setAttribute("data-listening", "true");
    showLabels(id, true);
    showStatus(id, "-status-listening");
  };

  const toggle = (id) => {
    if (running.has(id)) {
      stop(id);
    } else {
      start(id);
    }
  };

  // The note a string should sound, played so a reader can tune by ear -- which
  // is how a player tunes an instrument the microphone cannot hear, and how one
  // checks a tuner against their own ear.
  const tone = (id, midi) => {
    const Sound = window.AudioContext || window.webkitAudioContext;
    if (!Sound) {
      showStatus(id, "-status-unsupported");
      return;
    }
    if (!toneContext) {
      toneContext = new Sound();
    }
    if (toneContext.state === "suspended") {
      toneContext.resume();
    }

    const now = toneContext.currentTime;
    const frequency = frequencyOf(midi);
    const gain = toneContext.createGain();
    gain.gain.setValueAtTime(0, now);
    gain.gain.linearRampToValueAtTime(0.2, now + 0.02);
    gain.gain.setValueAtTime(0.2, now + 1.3);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 1.7);
    gain.connect(toneContext.destination);

    // Three partials rather than a pure tone: a sine alone is hard to hear
    // through the sound of a string being tuned, and a bare saw is unpleasant
    // to sit in front of.
    [1, 2, 3].forEach((harmonic) => {
      const oscillator = toneContext.createOscillator();
      const level = toneContext.createGain();
      oscillator.type = harmonic === 1 ? "triangle" : "sine";
      oscillator.frequency.value = frequency * harmonic;
      level.gain.value = 1 / (harmonic * harmonic);
      oscillator.connect(level);
      level.connect(gain);
      oscillator.start(now);
      oscillator.stop(now + 1.75);
    });

    const string = document.getElementById(id) &&
      Array.prototype.find.call(
        document.getElementById(id).querySelectorAll("[data-midi]"),
        (element) => Number.parseInt(element.getAttribute("data-midi"), 10) === midi,
      );
    if (string) {
      string.setAttribute("data-sounding", "true");
      setTimeout(() => string.removeAttribute("data-sounding"), 1750);
    }
  };

  const ready = () => {
    Array.prototype.forEach.call(
      document.querySelectorAll("[data-tuner]"),
      (widget) => {
        widget.hidden = false;
        showStatus(widget.id, "-status-idle");
        showLabels(widget.id, false);
      },
    );
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", ready);
  } else {
    ready();
  }

  return { start, stop, toggle, tone };
})();

function wikimusicTunerToggle(id) {
  wikimusicTuner.toggle(id);
}

function wikimusicTunerTone(id, midi) {
  wikimusicTuner.tone(id, midi);
}
