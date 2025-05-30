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

function startSongAutoScroll() {
  let autoScrollInterval = null
  let lastScrollTop = null

  const container = document.getElementById('ascii-content-container')
  container.scrollIntoView({ behavior: 'smooth' })

  const lineHeight = parseFloat(getComputedStyle(container).lineHeight) || 18
  const secondScrollSpeed = document.getElementById('second-scroll').value
  const lineScrollSpeed = document.getElementById('line-scroll').value
  const scrollAmount = lineHeight * lineScrollSpeed

  autoScrollInterval = setInterval(() => {
    if (lastScrollTop > document.documentElement.scrollTop || lastScrollTop >= (document.documentElement.scrollHeight - 1600)) {
      clearInterval(autoScrollInterval)
    }
    lastScrollTop = document.documentElement.scrollTop

    window.scrollBy({
      top: scrollAmount,
      behavior: 'smooth'
    })

  }, (secondScrollSpeed * 1000))
}


