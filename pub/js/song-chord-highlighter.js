/* wikimusic - the free music knowledge encyclopaedia
 *
 * SPDX-License-Identifier: MIT
 * Copyright © Josep Bigorra <jjbigorra@gmail.com>
*/

const highlightChords = (id) => {
  const preElement = document.getElementById(id)

  if (preElement) {
    const originalContent = preElement.textContent || ''

    // Regular expression to match chords.
    // It looks for:
    // - A-G (root note)
    // - Optional # (sharp) or b (flat)
    // - Optional 'm' (minor), 'maj' (major), 'min' (minor), 'dim' (diminished), 'aug' (augmented), 'sus' (suspended), 'add' (added)
    // - Optional numbers (7, 9, 11, 13 etc.)
    // - Optional / and another note for bass note (e.g., C/G)
    // - \b ensures word boundaries so "Amen" doesn't get "A" bolded
    const chordRegex = /\b[A-G](#|b)?(m|maj|min|dim|aug|sus|add)?\d*(\/[A-G](#|b)?)?\b/g

    preElement.textContent = ''

    let lastIndex = 0
    let match
    while ((match = chordRegex.exec(originalContent)) !== null) {
      const matchText = match[0]
      const matchIndex = match.index

      if (matchIndex > lastIndex) {
        preElement.appendChild(document.createTextNode(originalContent.slice(lastIndex, matchIndex)))
      }

      // The mark is the sheet's own (`pub/css/wikimusic.css'): the tab's ink, a
      // wash and a hairline, so the chords are found without the page shouting
      // and the box holds the columns the tab is read in.
      const strongElement = document.createElement('strong')
      strongElement.className = 'wm-chord'
      strongElement.textContent = matchText
      preElement.appendChild(strongElement)

      lastIndex = matchIndex + matchText.length
    }

    if (lastIndex < originalContent.length) {
      preElement.appendChild(document.createTextNode(originalContent.slice(lastIndex)))
    }
  } else {
    console.error(`Element with ID ${id} not found.`)
  }
};


