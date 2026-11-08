// Shows a small, dismissible thank-you card with tip buttons after a download click (once per visit).
(() => {
  const toast = document.getElementById('thanks');
  if (!toast) return;
  const seen = () => { try { return sessionStorage.getItem('tubemac-thanks') === '1'; } catch (e) { return false; } };
  const remember = () => { try { sessionStorage.setItem('tubemac-thanks', '1'); } catch (e) {} };
  document.querySelectorAll('[data-download]').forEach((a) => a.addEventListener('click', () => {
    if (seen()) return;
    remember();
    setTimeout(() => toast.classList.add('show'), 600);
  }));
  toast.querySelector('.close').addEventListener('click', () => toast.classList.remove('show'));
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') toast.classList.remove('show'); });
})();
