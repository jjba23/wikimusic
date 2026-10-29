/* wikimusic - the free music knowledge encyclopaedia
 *
 * SPDX-License-Identifier: MIT
 * Copyright © Josep Bigorra <jjbigorra@gmail.com>
*/

const highlightChords = (id) => {
  const preElement = document.getElementById(id)

  if (preElement) {
    const originalContent = preElement.textContent

    // Regular expression to match chords.
    // It looks for:
    // - A-G (root note)
    // - Optional # (sharp) or b (flat)
    // - Optional 'm' (minor), 'maj' (major), 'min' (minor), 'dim' (diminished), 'aug' (augmented), 'sus' (suspended), 'add' (added)
    // - Optional numbers (7, 9, 11, 13 etc.)
    // - Optional / and another note for bass note (e.g., C/G)
    // - \b ensures word boundaries so "Amen" doesn't get "A" bolded
    const chordRegex = /\b[A-G](#|b)?(m|maj|min|dim|aug|sus|add)?\d*(\/[A-G](#|b)?)?\b/g

    const boldedContent = originalContent.replace(chordRegex, (match) => {
      return `<strong class="font-black text-persia-pink-900 dark:text-persia-pink-300 font-mono">${match}</strong>`
    })

    preElement.innerHTML = boldedContent
  } else {
    console.error(`Element with ID ${id} not found.`)
  }
};


