// Droppy Version Config
// Single source of truth for version across all pages
const DROPPY_CONFIG = {
    version: '7.2.1',
    dmgUrl: 'https://github.com/iordv/Droppy/releases/latest/download/Droppy-7.2.1.dmg',
    releasesUrl: 'https://github.com/iordv/Droppy/releases/latest'
};

// Update all version badges on page load
document.addEventListener('DOMContentLoaded', function () {
    // Update version text elements
    document.querySelectorAll('.droppy-version').forEach(el => {
        el.textContent = 'v' + DROPPY_CONFIG.version;
    });

    // Update DMG download links
    document.querySelectorAll('[href*="Droppy-"]').forEach(el => {
        if (el.href.includes('.dmg')) {
            el.href = DROPPY_CONFIG.dmgUrl;
        }
    });
});
