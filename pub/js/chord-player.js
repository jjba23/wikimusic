/* wikimusic - the free music knowledge encyclopaedia
 *
 * SPDX-License-Identifier: MIT
 * Copyright © Josep Bigorra <jjbigorra@gmail.com>
*/

/// The chord guide on a song page, heard rather than only read.
///
/// A fingering is six characters, one per string from the lowest: a digit for
/// the fret it is held at and an `x' for a string left silent.  Turning that
/// into the notes a chord is made of needs nothing but the strings' own tuning
/// -- the same numbers a tab is written against -- so a reader can press a chord
/// and hear the thing they are being shown, and the page costs no file.
///
/// The sound is a pluck: a short attack and a long decay through a low-pass, one
/// string after another by a few dozen milliseconds, which is what a hand does.
/// Six oscillators at once is not a guitar, but it is in tune and it is the
/// right six notes, which is what a guide is for.

const wikimusicChordPlayer = (() => {
  // Standard tuning, lowest string first: what every fingering in the guide is
  // written against.
  const openStrings = [40, 45, 50, 55, 59, 64];
  const strumSeconds = 0.045;
  const ringSeconds = 1.6;
  const idleMilliseconds = 60;

  let context = null;
  let voices = [];
  let settling = null;

  const frequencyOf = (midi) => 440 * Math.pow(2, (midi - 69) / 12);

  // The frets a fingering names, or '() when it is not six strings of digits and
  // x's -- the guide writes `???' for a chord it does not know, and a chord
  // nobody can finger is not one to play.
  const fretsOf = (fingering) => {
    const frets = [];
    const written = String(fingering).trim();
    for (let index = 0; index < written.length; index++) {
      const character = written.charAt(index);
      if (character === "x" || character === "X" || character === "-") {
        frets.push(-1);
      } else if (character >= "0" && character <= "9") {
        frets.push(Number.parseInt(character, 10));
      }
    }
    return frets.length === openStrings.length ? frets : [];
  };

  const stop = () => {
    if (!context) {
      return;
    }
    const now = context.currentTime;
    clearTimeout(settling);
    voices.forEach((voice) => {
      try {
        voice.gain.gain.cancelScheduledValues(now);
        voice.gain.gain.setValueAtTime(0.0001, now);
        voice.oscillator.stop(now + 0.02);
      } catch (error) {}
    });
    voices = [];
  };

  const play = (fingering) => {
    const Sound = window.AudioContext || window.webkitAudioContext;
    const frets = fretsOf(fingering);
    if (!Sound || !frets.length) {
      return;
    }
    if (!context) {
      context = new Sound();
    }
    if (context.state === "suspended") {
      context.resume();
    }
    stop();

    const now = context.currentTime + 0.02;
    let plucked = 0;
    frets.forEach((fret, index) => {
      if (fret < 0) {
        return;
      }
      const when = now + plucked * strumSeconds;
      plucked += 1;
      const frequency = frequencyOf(openStrings[index] + fret);
      const gain = context.createGain();
      const filter = context.createBiquadFilter();
      const oscillator = context.createOscillator();
      filter.type = "lowpass";
      // The higher the note the more harmonics it is allowed: a chord is read by
      // its top notes, and a filter that dulled them would make every shape on
      // the page sound the same.
      filter.frequency.value = Math.min(9000, frequency * 7);
      oscillator.type = "triangle";
      oscillator.frequency.value = frequency;
      gain.gain.setValueAtTime(0, when);
      gain.gain.linearRampToValueAtTime(0.16, when + 0.006);
      gain.gain.exponentialRampToValueAtTime(0.0001, when + ringSeconds);
      oscillator.connect(filter);
      filter.connect(gain);
      gain.connect(context.destination);
      oscillator.start(when);
      oscillator.stop(when + ringSeconds + 0.05);
      voices.push({ gain, oscillator });
    });

    settling = setTimeout(() => {
      voices = [];
    }, (plucked * strumSeconds + ringSeconds + idleMilliseconds) * 1000);
  };

  return { play, stop };
})();

function wikimusicChordPlay(fingering) {
  wikimusicChordPlayer.play(fingering);
}

function wikimusicChordStop() {
  wikimusicChordPlayer.stop();
}
