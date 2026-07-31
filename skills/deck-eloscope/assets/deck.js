const slides = Array.from(document.querySelectorAll('.slide'));
  const total = slides.length;
  const counter = document.getElementById('counter');
  const dotsWrap = document.getElementById('dots');
  const progressBar = document.getElementById('progressBar');
  const prevBtn = document.getElementById('prevBtn');
  const nextBtn = document.getElementById('nextBtn');
  let idx = 0;

  slides.forEach((_, n) => {
    const d = document.createElement('button');
    d.className = 'dot' + (n === 0 ? ' active' : '');
    d.setAttribute('aria-label', 'Ir para slide ' + (n + 1));
    d.addEventListener('click', () => show(n));
    dotsWrap.appendChild(d);
  });
  const dots = Array.from(dotsWrap.children);

  function show(n) {
    idx = Math.max(0, Math.min(total - 1, n));
    slides.forEach((s, i) => s.classList.toggle('active', i === idx));
    dots.forEach((d, i) => d.classList.toggle('active', i === idx));
    counter.textContent = String(idx + 1).padStart(2, '0') + ' / ' + String(total).padStart(2, '0');
    progressBar.style.transform = 'scaleX(' + ((idx + 1) / total) + ')';
    document.body.classList.toggle('on-light', slides[idx].classList.contains('light'));
    prevBtn.disabled = idx === 0;
    nextBtn.disabled = idx === total - 1;
    slides[idx].scrollTop = 0;
  }

  prevBtn.addEventListener('click', () => show(idx - 1));
  nextBtn.addEventListener('click', () => show(idx + 1));
  document.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowRight' || e.key === ' ') { e.preventDefault(); show(idx + 1); }
    if (e.key === 'ArrowLeft') { e.preventDefault(); show(idx - 1); }
    if (e.key >= '1' && e.key <= '9') { const n = parseInt(e.key, 10) - 1; if (n < total) show(n); }
  });
  show(0);