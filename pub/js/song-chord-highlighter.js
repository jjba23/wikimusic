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

      const strongElement = document.createElement('strong')
      strongElement.className = 'font-black text-persia-pink-900 dark:text-persia-pink-300 font-mono'
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


