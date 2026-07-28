// Progressive enhancements. The page is fully readable and navigable without
// JavaScript; the deviation scale simply renders already settled at zero.

const prefersReducedMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;

/** Seconds either side of zero that the deviation scale spans. */
const SCALE_SPAN = 20;

/** Where the needle starts before it settles — an arrival running early. */
const INITIAL_DEVIATION = -18.4;

function wireNavToggle() {
  const toggle = document.querySelector(".nav-toggle");
  const nav = document.querySelector("#site-nav");
  if (!toggle || !nav) return;

  const setOpen = (open) => {
    toggle.setAttribute("aria-expanded", String(open));
    nav.toggleAttribute("data-open", open);
  };

  toggle.addEventListener("click", () => {
    setOpen(toggle.getAttribute("aria-expanded") !== "true");
  });

  nav.addEventListener("click", (event) => {
    if (event.target.closest("a")) setOpen(false);
  });
}

function highlightNavOnScroll() {
  const links = new Map(
    [...document.querySelectorAll('.site-nav a[href^="#"]')].map((link) => [
      link.hash.slice(1),
      link,
    ])
  );
  const sections = [...links.keys()].map((id) => document.getElementById(id)).filter(Boolean);
  if (!sections.length) return;

  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        for (const link of links.values()) link.removeAttribute("aria-current");
        links.get(entry.target.id)?.setAttribute("aria-current", "true");
      }
    },
    { rootMargin: "-45% 0px -50% 0px" }
  );

  sections.forEach((section) => observer.observe(section));
}

function formatDeviation(seconds) {
  const magnitude = Math.abs(seconds).toFixed(1).padStart(4, "0");
  if (Math.abs(seconds) < 0.05) return magnitude;
  return (seconds < 0 ? "−" : "+") + magnitude;
}

/**
 * Damped oscillation settling to exactly zero at t = 1, the way a mechanical
 * movement converges on its index rather than sliding linearly into place.
 */
function settleCurve(t) {
  return INITIAL_DEVIATION * Math.exp(-4 * t) * Math.cos(8.5 * t) * (1 - t);
}

function settleDeviationScale() {
  const needle = document.querySelector("[data-needle]");
  const readout = document.querySelector("[data-readout]");
  if (!needle || !readout) return;

  const render = (seconds) => {
    const position = 50 + (seconds / SCALE_SPAN) * 50;
    needle.style.setProperty("--pos", `${Math.min(100, Math.max(0, position))}%`);
    readout.textContent = formatDeviation(seconds);
  };

  if (prefersReducedMotion) {
    render(0);
    return;
  }

  const duration = 1900;
  let start = null;

  const frame = (now) => {
    start ??= now;
    const t = Math.min(1, (now - start) / duration);
    render(settleCurve(t));
    if (t < 1) requestAnimationFrame(frame);
  };

  render(INITIAL_DEVIATION);
  requestAnimationFrame(frame);
}

function stampCurrentYear() {
  const year = String(new Date().getFullYear());
  document.querySelectorAll("[data-current-year]").forEach((el) => {
    el.textContent = year;
  });
}

wireNavToggle();
highlightNavOnScroll();
settleDeviationScale();
stampCurrentYear();
