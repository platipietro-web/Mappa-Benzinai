const functions = require('firebase-functions');
const https = require('https');
const http = require('http');

// URL ufficiali MIMIT
const MIMIT_STATIONS_URL =
  'https://www.mimit.gov.it/images/exportCSV/anagrafica_impianti_attivi.csv';
const MIMIT_PRICES_URL =
  'https://www.mimit.gov.it/images/exportCSV/prezzi_alle_8.csv';

// Cache in-memory (si azzera a ogni cold start, ma è sufficiente)
let cachedStations = null;
let cachedPrices = null;
let lastCacheTime = null;
const CACHE_DURATION_MS = 6 * 60 * 60 * 1000; // 6 ore

// ─── Helper: scarica un URL come testo ────────────────────────────────────────
function fetchText(url) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https') ? https : http;
    client
      .get(url, { headers: { 'User-Agent': 'MappaPrezziBenzina/1.0' } }, (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => resolve(data));
      })
      .on('error', reject);
  });
}

// ─── Helper: aggiungi CORS headers ────────────────────────────────────────────
function setCorsHeaders(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
}

// ─── Funzione: /mimitStations ─────────────────────────────────────────────────
exports.mimitStations = functions
  .runWith({ timeoutSeconds: 120, memory: '512MB' })
  .https.onRequest(async (req, res) => {
    setCorsHeaders(res);
    if (req.method === 'OPTIONS') return res.status(204).send('');

    try {
      const now = Date.now();
      const cacheValid =
        cachedStations &&
        lastCacheTime &&
        now - lastCacheTime < CACHE_DURATION_MS;

      if (!cacheValid) {
        console.log('Downloading MIMIT stations CSV...');
        cachedStations = await fetchText(MIMIT_STATIONS_URL);
        lastCacheTime = now;
        console.log(`Stations CSV size: ${cachedStations.length} bytes`);
      } else {
        console.log('Serving cached stations CSV');
      }

      res.set('Content-Type', 'text/csv; charset=utf-8');
      res.set('Cache-Control', 'public, max-age=21600'); // 6 ore
      res.status(200).send(cachedStations);
    } catch (err) {
      console.error('Error fetching stations CSV:', err);
      res.status(500).json({ error: 'Failed to fetch stations data' });
    }
  });

// ─── Funzione: /mimitPrices ───────────────────────────────────────────────────
exports.mimitPrices = functions
  .runWith({ timeoutSeconds: 120, memory: '512MB' })
  .https.onRequest(async (req, res) => {
    setCorsHeaders(res);
    if (req.method === 'OPTIONS') return res.status(204).send('');

    try {
      const now = Date.now();
      const cacheValid =
        cachedPrices &&
        lastCacheTime &&
        now - lastCacheTime < CACHE_DURATION_MS;

      if (!cacheValid) {
        console.log('Downloading MIMIT prices CSV...');
        cachedPrices = await fetchText(MIMIT_PRICES_URL);
        lastCacheTime = now;
        console.log(`Prices CSV size: ${cachedPrices.length} bytes`);
      } else {
        console.log('Serving cached prices CSV');
      }

      res.set('Content-Type', 'text/csv; charset=utf-8');
      res.set('Cache-Control', 'public, max-age=21600');
      res.status(200).send(cachedPrices);
    } catch (err) {
      console.error('Error fetching prices CSV:', err);
      res.status(500).json({ error: 'Failed to fetch prices data' });
    }
  });