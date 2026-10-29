/* wikimusic - the free music knowledge encyclopaedia
 *
 * SPDX-License-Identifier: MIT
 * Copyright © Josep Bigorra <jjbigorra@gmail.com>
*/

/// Strength, shown while a password is being chosen rather than after it has
/// been sent.
///
/// The rule this measures is not invented here.  It is the same estimate
/// `bewaking` makes server-side -- `password-strength', whose score
/// `strong-password?' compares against three -- and the two have to agree,
/// because the page and the server would otherwise disagree about the same
/// string: a meter that says "strong" over a password the server then refuses
/// is worse than no meter at all.  So the model below is a mirror of that one,
/// and it is kept deliberately literal:
///
///   entropy = length x log2(sum of the class sizes present)
///   penalties: a common password scores nothing at all, and four bits are
///   taken off for every character of a run past the second -- a run of the
///   same character ("aaa") or of consecutive ones ("abcd", "4321") -- plus
///   six bits for anything shorter than eight characters
///   score = 0 under 28 bits, 1 under 40, 2 under 60, 3 under 80, else 4
///
/// Two things are approximated, and only in the direction that refuses more
/// rather than less: character classes are read with the Unicode categories a
/// letter, a digit, a lower-case and an upper-case character belong to, so a
/// script's own alphabet is counted the way the server counts it, and the list
/// of common passwords is the same list the server holds.  The server is still
/// the one that decides: this only spares a reader the round trip of being
/// told so after submitting.
///
/// The words are the page's.  It writes its own label for each of the five
/// scores, its own sentence for a password typed twice in two different ways,
/// and its own line stating the rule; this file only decides which of them to
/// show.  A page may hold more than one of these, so everything is looked up
/// from the wrapper it is found in.
///
/// The contract with the view is one attribute and six more beside it:
///
///   data-password-strength        the wrapper, holding the field or fields
///   data-label-very-weak          the page's words for each score, 0 to 4
///   data-label-weak
///   data-label-fair
///   data-label-strong
///   data-label-very-strong
///   data-mismatch                 shown when two fields differ
///
/// Inside the wrapper, the fields are found by their type: the first is the
/// password being chosen, and a second one, when the page writes one, is the
/// confirmation it is compared with.

const wikimusicPasswordStrength = (() => {
  // The same list `bewaking' holds, and the same pool sizes.  A password that
  // appears here scores nothing however long or varied it is.
  const commonPasswords = new Set([
    "123456", "password", "12345678", "qwerty", "123456789", "12345", "1234",
    "111111", "1234567", "dragon", "123123", "baseball", "abc123", "football",
    "monkey", "letmein", "shadow", "master", "666666", "qwertyuiop", "123321",
    "mustang", "1234567890", "michael", "654321", "superman", "1qaz2wsx",
    "7777777", "121212", "000000", "iloveyou", "admin", "welcome", "login",
    "princess", "solo", "starwars", "passw0rd", "hello", "freedom", "whatever",
  ]);

  const poolSizes = {
    lowercase: 26,
    uppercase: 26,
    digit: 10,
    symbol: 33,
  };

  // The highest score there is, which is also the last label the page writes.
  const strongest = 4;

  const labelKeys = [
    "very-weak",
    "weak",
    "fair",
    "strong",
    "very-strong",
  ];

  // Every character that is not a letter, a digit or whitespace counts as a
  // symbol, which is how the server's own character set is built.
  const letter = /\p{L}/u;
  const lower = /\p{Ll}/u;
  const upper = /\p{Lu}/u;
  const digit = /[0-9]/u;
  const space = /\s/u;

  const classesOf = (password) => {
    const characters = [...password];
    const present = new Set();
    if (characters.some((c) => lower.test(c))) {
      present.add("lowercase");
    }
    if (characters.some((c) => upper.test(c))) {
      present.add("uppercase");
    }
    if (characters.some((c) => digit.test(c))) {
      present.add("digit");
    }
    if (characters.some((c) =>
      !space.test(c) && !letter.test(c) && !digit.test(c))) {
      present.add("symbol");
    }
    return present;
  };

  const poolSizeOf = (classes) => {
    let total = 0;
    classes.forEach((name) => {
      total += poolSizes[name] || 0;
    });
    return Math.max(1, total);
  };

  const entropyOf = (password, classes) => {
    if (password.length === 0) {
      return 0;
    }
    return password.length * (Math.log(poolSizeOf(classes)) / Math.log(2));
  };

  // The longest run of adjacent characters for which `same?' holds -- the
  // same character twice in a row, or two characters that are neighbours in
  // the alphabet or on the number row.
  const longestRun = (password, same) => {
    const codes = [...password].map((c) => c.codePointAt(0));
    if (codes.length < 2) {
      return codes.length;
    }
    let longest = 1;
    let current = 1;
    for (let index = 1; index < codes.length; index++) {
      if (same(codes[index - 1], codes[index])) {
        current += 1;
        longest = Math.max(longest, current);
      } else {
        current = 1;
      }
    }
    return longest;
  };

  const repeatedRun = (password) => longestRun(password, (a, b) => a === b);

  const sequentialRun = (password) =>
    longestRun(password, (a, b) => Math.abs(a - b) === 1);

  const scoreOf = (password) => {
    const length = password.length;
    const classes = classesOf(password);
    const raw = entropyOf(password, classes);
    const common = commonPasswords.has(password.toLowerCase());
    const penalty = (common ? raw : 0) +
      4 * Math.max(0, repeatedRun(password) - 2) +
      4 * Math.max(0, sequentialRun(password) - 2) +
      (length < 8 ? 6 : 0);
    const entropy = Math.max(0, raw - penalty);
    if (common || length < 1 || entropy < 28) {
      return 0;
    }
    if (entropy < 40) {
      return 1;
    }
    if (entropy < 60) {
      return 2;
    }
    if (entropy < 80) {
      return 3;
    }
    return strongest;
  };

  const attach = (wrapper) => {
    const fields = wrapper.querySelectorAll('input[type="password"]');
    if (fields.length === 0) {
      return;
    }
    const chosen = fields[0];
    const confirmation = fields.length > 1 ? fields[1] : null;
    const bar = wrapper.querySelector("progress");
    const saying = wrapper.querySelector("[data-password-strength-saying]");

    const labels = labelKeys.map((key) =>
      wrapper.getAttribute("data-label-" + key) || "");
    const mismatch = wrapper.getAttribute("data-mismatch") || "";

    const show = () => {
      const password = chosen.value;
      const score = scoreOf(password);
      const differs = Boolean(confirmation) &&
        confirmation.value.length > 0 &&
        confirmation.value !== password;
      if (bar) {
        // The bar is decoration beside the sentence, so it is only given a
        // value when there is something to measure.
        bar.value = password.length === 0 ? 0 : score;
      }
      if (saying) {
        if (password.length === 0) {
          saying.textContent = "";
          return;
        }
        const said = labels[score] || "";
        saying.textContent = differs ? said + " — " + mismatch : said;
      }
    };

    chosen.addEventListener("input", show);
    if (confirmation) {
      confirmation.addEventListener("input", show);
    }
    show();
  };

  const ready = () => {
    document.querySelectorAll("[data-password-strength]").forEach(attach);
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", ready);
  } else {
    ready();
  }

  return { scoreOf };
})();
