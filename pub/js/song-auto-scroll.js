/* wikimusic - the free music knowledge encyclopaedia
 *
 * SPDX-License-Identifier: MIT
 * Copyright © Josep Bigorra <jjbigorra@gmail.com>
*/

/// Scrolling a tab down the screen, so both hands stay on the instrument.
///
/// What this replaces moved the page a block of lines once a second with
/// `behavior: smooth'.  That is two motions at once -- the browser's easing and
/// the next step landing on top of it -- so the tab stuttered down the screen
/// instead of travelling, the speed was fixed once the button was pressed, and
/// it gave up 1600px before the end of the page whatever the tab was showing.
/// A prompter travels at a speed; it does not take steps.
///
/// So the scroll happens in the frame loop: each frame moves the share of a line
/// that the frame lasted, and the menu on the tab's own sheet is read as lines a
/// second, so a reader can change it while it runs and feel it.  The reader's
/// own hand wins -- a wheel turn, a touch drag, a scroll key or a dragged
/// scrollbar stops it -- and it stops by itself at the last line of the tab
/// rather than at the end of the page, because the tab is the music and what
/// follows it is not.
///
/// A scrollbar drag is the one the page is never told about: a scrollbar is the
/// browser's, not the document's, so dragging it fires no event a page can
/// hear.  It does leave a trace, though -- the page has moved to somewhere this
/// loop did not put it.  So every frame records the position it scrolled to,
/// and a frame that finds the page anywhere else stops the scroll instead of
/// scrolling again.  Our own move is written down the moment it is made, so the
/// loop can never mistake itself for the reader.

const wikimusicSongScroll = (() => {
  let frame = null
  let last = 0
  let carry = 0
  let tab = null
  let speedMenu = null
  let lineHeight = 18
  // Where the last frame put the page.  A scroll that lands anywhere else is
  // somebody else's.
  let placed = 0

  const running = () => frame !== null

  const linesPerSecond = () => Number(speedMenu.value) || 4

  // The furthest position worth reaching: the last line of the tab at the foot
  // of the viewport, so the scroll ends on the music and not on the footer.
  const endOfTab = () =>
    tab.getBoundingClientRect().bottom + window.scrollY - window.innerHeight

  const stop = () => {
    if (frame !== null) {
      cancelAnimationFrame(frame)
    }
    frame = null
    carry = 0
    const button = document.getElementById('start-autoscroll')
    if (button) button.setAttribute('aria-pressed', 'false')
  }

  const step = (now) => {
    // A frame that arrives late -- a busy tab, a lost frame -- must not jump the
    // page: a prompter that skips a line has lost the reader their place.
    const elapsed = Math.min((now - last) / 1000, 0.25)
    last = now

    // Two pixels of slack: a browser is free to round a scroll to the device
    // pixel, and the frame that follows is where the next whole line begins.
    if (Math.abs(window.scrollY - placed) > 2) {
      stop()
      return
    }

    // A tab's foot is a measured position and so rarely a whole pixel: a
    // scroll cannot reach it exactly, and a test for equality would leave the
    // scroll running for ever at the last line.
    const end = endOfTab()
    if (window.scrollY + 1 >= end) {
      stop()
      return
    }

    carry += lineHeight * linesPerSecond() * elapsed
    const pixels = Math.floor(carry)
    if (pixels > 0) {
      carry -= pixels
      // `instant' and not the page's own `smooth': a smooth scroll is an
      // animation, and a frame that starts one every 16ms is the stutter this
      // replaced.  The travel is the animation.
      window.scrollTo({
        top: Math.min(window.scrollY + pixels, end),
        behavior: 'instant'
      })
      placed = window.scrollY
    }
    frame = requestAnimationFrame(step)
  }

  const start = () => {
    if (running()) {
      stop()
      return
    }
    tab = document.getElementById('ascii-content-container')
    speedMenu = document.getElementById('scroll-speed')
    if (!tab || !speedMenu) return

    const top = tab.getBoundingClientRect().top + window.scrollY
    if (window.scrollY < top) window.scrollTo({ top, behavior: 'instant' })
    placed = window.scrollY
    if (window.scrollY + 1 >= endOfTab()) return

    lineHeight = parseFloat(getComputedStyle(tab).lineHeight) || 18
    last = performance.now()
    carry = 0
    const button = document.getElementById('start-autoscroll')
    if (button) button.setAttribute('aria-pressed', 'true')
    frame = requestAnimationFrame(step)
  }

  const scrollKeys = ['ArrowUp', 'ArrowDown', 'PageUp', 'PageDown', 'Home', 'End']
  window.addEventListener('wheel', stop, { passive: true })
  window.addEventListener('touchmove', stop, { passive: true })
  window.addEventListener('keydown', (event) => {
    if (scrollKeys.includes(event.key)) stop()
  })

  return { start, stop, running }
})()

function startSongAutoScroll() {
  wikimusicSongScroll.start()
}
