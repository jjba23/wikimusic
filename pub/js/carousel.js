/* wikimusic - the free music knowledge encyclopaedia
 *
 * SPDX-License-Identifier: MIT
 * Copyright © Josep Bigorra <jjbigorra@gmail.com>
*/

/// The dots and the count under a carousel.
///
/// The track itself is the page's: it is a list of slides that scrolls
/// sideways with snap points, so it works with no script at all -- a reader
/// swipes it on a phone and drags it on a desk.  What a track cannot say is
/// *where in the set* a reader is, because a scrolled list has no notion of a
/// "current" slide until something counts.  That is all this adds: a dot per
/// slide, the one being looked at drawn long, and "2 / 4" beside it, all
/// driven by the track's own scroll position rather than by an index this
/// script keeps -- so a swipe, an arrow the framework draws, and a dot all stay
/// in step with each other.
///
/// A page with one picture gets none of this: a dot for a single slide is an
/// ornament, and `entity-details' only builds a carousel when there are two.

const wikimusicCarousel = (() => {
  const dotSuffix = "-dot-";

  const slidesOf = (track) =>
    Array.prototype.filter.call(
      track.children,
      (child) => child.classList && child.classList.contains("carousel-list-item"),
    );

  // The slide nearest the middle of the track, which is the one a reader is
  // looking at: a track shows a share of its neighbours on purpose, so the
  // first slide that is fully in view is not the answer at the end of the set.
  const currentOf = (track, slides) => {
    const middle = track.scrollLeft + track.clientWidth / 2;
    let best = 0;
    let bestDistance = Infinity;
    slides.forEach((slide, index) => {
      const centre = slide.offsetLeft + slide.offsetWidth / 2;
      const distance = Math.abs(centre - middle);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = index;
      }
    });
    return best;
  };

  const goTo = (track, slide) => {
    const left = slide.offsetLeft - (track.clientWidth - slide.offsetWidth) / 2;
    track.scrollTo({ left, behavior: "smooth" });
  };

  const build = (track) => {
    const slides = slidesOf(track);
    if (slides.length < 2 || track.dataset.wmCarouselReady) {
      return;
    }
    track.dataset.wmCarouselReady = "true";

    const shell = document.createElement("div");
    shell.className = "wm-carousel";
    track.parentNode.insertBefore(shell, track);
    shell.appendChild(track);

    const dots = document.createElement("div");
    dots.className = "wm-carousel-dots";
    dots.setAttribute("role", "tablist");
    dots.setAttribute("aria-label", track.getAttribute("aria-label") || "pictures");

    const count = document.createElement("p");
    count.className = "wm-carousel-count";
    count.setAttribute("aria-live", "polite");

    const buttons = slides.map((slide, index) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "wm-carousel-dot";
      button.setAttribute("role", "tab");
      button.setAttribute("aria-label", String(index + 1));
      button.addEventListener("click", () => goTo(track, slide));
      dots.appendChild(button);
      return button;
    });

    const draw = () => {
      const current = currentOf(track, slides);
      buttons.forEach((button, index) => {
        button.setAttribute("aria-current", index === current ? "true" : "false");
        button.setAttribute("aria-selected", index === current ? "true" : "false");
      });
      count.textContent = `${current + 1} / ${slides.length}`;
    };

    // The track is reachable by keyboard so the arrows below have somewhere to
    // arrive, and the keys move one picture at a time rather than one pixel.
    track.tabIndex = 0;
    track.addEventListener("keydown", (event) => {
      const current = currentOf(track, slides);
      if (event.key === "ArrowRight" && current < slides.length - 1) {
        event.preventDefault();
        goTo(track, slides[current + 1]);
      } else if (event.key === "ArrowLeft" && current > 0) {
        event.preventDefault();
        goTo(track, slides[current - 1]);
      }
    });

    let waiting = null;
    track.addEventListener("scroll", () => {
      if (waiting) {
        return;
      }
      waiting = window.setTimeout(() => {
        waiting = null;
        draw();
      }, 80);
    });

    shell.appendChild(dots);
    shell.appendChild(count);
    draw();
  };

  const ready = () => {
    Array.prototype.forEach.call(
      document.querySelectorAll(".carousel-list"),
      build,
    );
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", ready);
  } else {
    ready();
  }

  return { ready, dotSuffix };
})();
