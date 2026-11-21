/* wikimusic - the free music knowledge encyclopaedia
 *
 * SPDX-License-Identifier: MIT
 * Copyright © Josep Bigorra <jjbigorra@gmail.com>
*/

/// Marking the chords a tab names.
///
/// A chord name is a letter and a handful of symbols, so a pattern that asks
/// only "is this a chord name?" answers yes to the `Am' in `Metallica - Am I
/// Evil?' and the `A' in `[Riff A.1]'.  What tells those apart from a chord is
/// not the name but the line: a tab writes its chords on a line of their own,
/// above the notes or the words, and a line of nothing but chord names is a
/// chord line.  A title or a heading is a sentence, and a sentence is mostly
/// not chords.
///
/// So the mark is decided line by line: on a line where every word is a chord
/// name, each one is marked; on any other line nothing is.  The line is written
/// back as the same characters -- the mark wraps a name and adds no space --
/// because a tab is read by its columns.
///
/// The marks are drawn as the page is drawn, not on a press: a chord is part of
/// how the tab is read, like the columns it sits in, and a mode a reader has to
/// turn on is a tab they read once without the chords and then again with them.

// A chord name: a root, an accidental, a quality or a number of them, and a
// bass note after a slash.  Matched against a whole token, never a fragment.
const wikimusicChordName =
  /^[A-G][#b]?(?:(?:maj|min|dim|aug|sus|add|alt|no|m)\d*|\d+|[#b]\d+|°|ø|\+)*(?:\/[A-G][#b]?)?$/

// The brackets, bars and full stops around a chord are the line's punctuation,
// not part of its name.
const wikimusicChordCore = (token) =>
  token.replace(/^[([{<]+/, '').replace(/[)\]}>.,;:*]+$/, '')

// `x2' marks a repeat in a chord line; it is not a word of the line.  One or two
// digits only, or a fingering (`x02210') would read as a repeat too.
const wikimusicRepeatMark = (token) => /^x\d{1,2}$/i.test(wikimusicChordCore(token))

const wikimusicChordToken = (token) =>
  wikimusicChordName.test(wikimusicChordCore(token))

const wikimusicChordLine = (tokens) => {
  const words = tokens
    .map(wikimusicChordCore)
    .filter((word) => /[A-Za-z]/.test(word) && !wikimusicRepeatMark(word))
  return words.length > 0 && words.every((word) => wikimusicChordName.test(word))
}

const highlightChords = (id) => {
  const preElement = document.getElementById(id)

  if (!preElement) {
    console.error(`Element with ID ${id} not found.`)
    return
  }

  const originalContent = preElement.textContent || ''
  // Whitespace runs are kept as pieces of their own, so the line is written
  // back character for character and its columns do not move.
  const lines = originalContent.split('\n')

  preElement.textContent = ''

  lines.forEach((line, index) => {
    const pieces = line.match(/\s+|\S+/g) || []
    const onChordLine = wikimusicChordLine(pieces)

    pieces.forEach((piece) => {
      if (!onChordLine || !wikimusicChordToken(piece)) {
        preElement.appendChild(document.createTextNode(piece))
        return
      }

      const name = wikimusicChordCore(piece)
      const start = piece.indexOf(name)
      if (start > 0) {
        preElement.appendChild(document.createTextNode(piece.slice(0, start)))
      }

      const strongElement = document.createElement('strong')
      strongElement.className = 'wm-chord'
      strongElement.textContent = name
      preElement.appendChild(strongElement)

      const end = start + name.length
      if (end < piece.length) {
        preElement.appendChild(document.createTextNode(piece.slice(end)))
      }
    })

    if (index < lines.length - 1) {
      preElement.appendChild(document.createTextNode('\n'))
    }
  })
}

const wikimusicMarkTabChords = () => {
  if (document.getElementById('ascii-content-container')) {
    highlightChords('ascii-content-container')
  }
}

// The script is inlined in the page's head, so on a fresh page the tab has not
// been parsed yet; on a page that is already parsed -- a prerendered one, or one
// the browser restores -- the tab is there to be marked at once.
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', wikimusicMarkTabChords)
} else {
  wikimusicMarkTabChords()
}
