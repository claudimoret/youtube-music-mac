// Thank-you dialog after a download click (once per visit): next steps + optional tip buttons.
(() => {
  const modal = document.getElementById('thanks');
  if (!modal) return;
  const seen = () => { try { return sessionStorage.getItem('tubemac-thanks') === '1'; } catch (e) { return false; } };
  const remember = () => { try { sessionStorage.setItem('tubemac-thanks', '1'); } catch (e) {} };
  let lastFocus = null;
  const open = () => {
    lastFocus = document.activeElement;
    modal.classList.add('show');
    modal.querySelector('.close').focus({ preventScroll: true });
  };
  const close = () => {
    modal.classList.remove('show');
    if (lastFocus) lastFocus.focus({ preventScroll: true });
  };
  document.querySelectorAll('[data-download]').forEach((a) => a.addEventListener('click', () => {
    if (seen()) return;
    remember();
    setTimeout(open, 400);
  }));
  modal.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', close));
  modal.addEventListener('click', (e) => { if (e.target === modal) close(); });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && modal.classList.contains('show')) close(); });
})();
