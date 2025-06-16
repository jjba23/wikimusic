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
      return `<strong class="font-black text-black dark:text-white font-sans">${match}</strong>`
    })

    preElement.innerHTML = boldedContent
  } else {
    console.error(`Element with ID ${id} not found.`)
  }
};


