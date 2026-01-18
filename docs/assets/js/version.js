// Droppy Version Config
// Automatically fetches latest version from GitHub releases

const DROPPY_CONFIG = {
    // Fallback values if GitHub API fails
    version: '8.2.1',
    dmgUrl: 'https://github.com/iordv/Droppy/releases/latest/download/Droppy-8.2.1.dmg',
    releasesUrl: 'https://github.com/iordv/Droppy/releases/latest',

    // GitHub API endpoint
    apiUrl: 'https://api.github.com/repos/iordv/Droppy/releases/latest'
};

// Cache key for localStorage
const CACHE_KEY = 'droppy_version_cache';
const CACHE_DURATION = 1000 * 60 * 30; // 30 minutes

// Get cached version or fetch from GitHub
async function getLatestVersion() {
    // Check cache first
    const cached = localStorage.getItem(CACHE_KEY);
    if (cached) {
        try {
            const { version, dmgUrl, timestamp } = JSON.parse(cached);
            if (Date.now() - timestamp < CACHE_DURATION) {
                return { version, dmgUrl };
            }
        } catch (e) {
            localStorage.removeItem(CACHE_KEY);
        }
    }

    // Fetch from GitHub API
    try {
        const response = await fetch(DROPPY_CONFIG.apiUrl);
        if (!response.ok) throw new Error('API request failed');

        const data = await response.json();
        const version = data.tag_name.replace(/^v/, ''); // Remove 'v' prefix
        const dmgAsset = data.assets.find(a => a.name.endsWith('.dmg'));
        const dmgUrl = dmgAsset ? dmgAsset.browser_download_url : DROPPY_CONFIG.dmgUrl;

        // Cache the result
        localStorage.setItem(CACHE_KEY, JSON.stringify({
            version,
            dmgUrl,
            timestamp: Date.now()
        }));

        return { version, dmgUrl };
    } catch (error) {
        console.warn('Failed to fetch version from GitHub, using fallback:', error);
        return {
            version: DROPPY_CONFIG.version,
            dmgUrl: DROPPY_CONFIG.dmgUrl
        };
    }
}

// Update all version elements on page load
document.addEventListener('DOMContentLoaded', async function () {
    const { version, dmgUrl } = await getLatestVersion();

    // Update version text elements
    document.querySelectorAll('.droppy-version').forEach(el => {
        el.textContent = 'v' + version;
    });

    // Update DMG download links
    document.querySelectorAll('a[href*="Droppy"]').forEach(el => {
        if (el.href.includes('.dmg') || el.href.includes('/download/')) {
            el.href = dmgUrl;
        }
    });
});
