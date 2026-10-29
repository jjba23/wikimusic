/* wikimusic - the free music knowledge encyclopaedia
 *
 * SPDX-License-Identifier: MIT
 * Copyright © Josep Bigorra <jjbigorra@gmail.com>
*/

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


