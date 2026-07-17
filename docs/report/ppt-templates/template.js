const revealTargets = document.querySelectorAll('.slide-shell, .template-card');

const observer = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) {
      entry.target.classList.add('visible');
      observer.unobserve(entry.target);
    }
  });
}, {
  rootMargin: '0px 0px -8% 0px',
  threshold: 0.12
});

revealTargets.forEach((target) => observer.observe(target));

const slides = Array.from(document.querySelectorAll('.slide-shell'));

const requestedSlide = Number.parseInt(new URLSearchParams(window.location.search).get('slide') ?? '', 10);
if (Number.isInteger(requestedSlide) && requestedSlide >= 1 && requestedSlide <= slides.length) {
  document.body.classList.add('single-slide-preview');
  slides.forEach((slide, index) => {
    if (index !== requestedSlide - 1) {
      slide.hidden = true;
    }
  });
  slides[requestedSlide - 1].classList.add('visible');
}

function moveToSlide(direction) {
  if (slides.length === 0) return;

  const viewportMiddle = window.scrollY + window.innerHeight / 2;
  let currentIndex = 0;
  let smallestDistance = Number.POSITIVE_INFINITY;

  slides.forEach((slide, index) => {
    const middle = slide.offsetTop + slide.offsetHeight / 2;
    const distance = Math.abs(middle - viewportMiddle);
    if (distance < smallestDistance) {
      smallestDistance = distance;
      currentIndex = index;
    }
  });

  const targetIndex = Math.max(0, Math.min(slides.length - 1, currentIndex + direction));
  slides[targetIndex].scrollIntoView({ behavior: 'smooth', block: 'center' });
}

window.addEventListener('keydown', (event) => {
  if (event.key === 'ArrowDown' || event.key === 'PageDown') {
    event.preventDefault();
    moveToSlide(1);
  }
  if (event.key === 'ArrowUp' || event.key === 'PageUp') {
    event.preventDefault();
    moveToSlide(-1);
  }
});
