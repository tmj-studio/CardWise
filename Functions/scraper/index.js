/**
 * CardWise Credit Card Rewards Scraper
 *
 * This script scrapes credit card reward information from official issuer websites
 * and aggregates the data into a unified format for the CardWise app.
 *
 * Usage:
 * - npm run scrape        # Run all scrapers
 * - npm run scrape:chase  # Run Chase scraper only
 * - npm run upload        # Upload scraped data to Firestore
 * - npm run full          # Scrape and upload
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

// Import validation
const { validateAllCards, printValidationSummary } = require('./utils/schema-validator');

// Import individual scrapers
const chaseScraper = require('./scrapers/chase');
const amexScraper = require('./scrapers/amex');
const citiScraper = require('./scrapers/citi');
const capitaloneScraper = require('./scrapers/capitalone');
const discoverScraper = require('./scrapers/discover');
const bofaScraper = require('./scrapers/bofa');
const wellsfargoScraper = require('./scrapers/wellsfargo');
const usbankScraper = require('./scrapers/usbank');
const othersScraper = require('./scrapers/others');

const OUTPUT_FILE = path.join(__dirname, 'scraped-cards.json');

/**
 * Check if a URL is accessible (returns HTTP status code)
 * Uses GET with range header to minimize data transfer (some sites block HEAD)
 */
function checkImageUrl(url) {
  return new Promise((resolve) => {
    const client = url.startsWith('https') ? https : http;
    const options = {
      method: 'GET',
      timeout: 10000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'Range': 'bytes=0-0'  // Only fetch first byte
      }
    };
    const req = client.request(url, options, (res) => {
      res.destroy(); // Don't need the body
      // 206 = partial content (range request worked), 200 = full content
      const ok = res.statusCode === 200 || res.statusCode === 206 || res.statusCode === 304;
      resolve({ status: res.statusCode, ok });
    });
    req.on('error', (err) => resolve({ status: 0, ok: false, error: err.message }));
    req.on('timeout', () => { req.destroy(); resolve({ status: 0, ok: false, error: 'timeout' }); });
    req.end();
  });
}

/**
 * Check for duplicate categories in cards (warning only, doesn't fail validation)
 * Note: Duplicates with different 'note' fields are allowed (e.g., portal-specific rewards)
 */
function checkDuplicateCategories(cards) {
  console.log('\n🔍 Checking for duplicate categories...');
  const cardsWithDuplicates = [];

  for (const card of cards) {
    if (!card.categoryRewards || card.categoryRewards.length === 0) continue;

    // Only count as duplicate if same category WITHOUT note distinction
    const withoutNote = card.categoryRewards.filter(r => !r.note);
    const categories = withoutNote.map(r => r.category);
    const duplicates = categories.filter((c, i) => categories.indexOf(c) !== i);

    if (duplicates.length > 0) {
      cardsWithDuplicates.push({
        card: card.name,
        duplicates: [...new Set(duplicates)]
      });
    }
  }

  if (cardsWithDuplicates.length === 0) {
    console.log('   ✅ No duplicate categories found');
  } else {
    console.log(`   ⚠️  Found ${cardsWithDuplicates.length} cards with duplicate categories:`);
    cardsWithDuplicates.forEach(c => {
      console.log(`   - ${c.card}: ${c.duplicates.join(', ')}`);
    });
  }

  return cardsWithDuplicates;
}

/**
 * Validate all image URLs are accessible
 */
async function validateImageUrls(cards) {
  console.log('\n🖼️  Validating image URLs...');
  const results = { valid: 0, invalid: 0, missing: 0, errors: [] };

  for (const card of cards) {
    if (!card.imageURL) {
      results.missing++;
      continue;
    }

    const check = await checkImageUrl(card.imageURL);
    if (check.ok) {
      results.valid++;
    } else {
      results.invalid++;
      const reason = check.error || `HTTP ${check.status}`;
      results.errors.push({ card: card.name, url: card.imageURL, reason });
    }
  }

  // Print results
  console.log(`   ✅ Valid: ${results.valid}`);
  console.log(`   ❌ Invalid: ${results.invalid}`);
  console.log(`   ⚠️  Missing: ${results.missing}`);

  if (results.errors.length > 0) {
    console.log('\n   Invalid image URLs:');
    results.errors.forEach(e => {
      console.log(`   - ${e.card}: ${e.reason}`);
    });
  }

  return results;
}

async function runAllScrapers() {
  console.log('🚀 Starting SmartCard Credit Card Scraper...\n');

  const allCards = [];
  const errors = [];

  const scrapers = [
    { name: 'Chase', fn: chaseScraper },
    { name: 'American Express', fn: amexScraper },
    { name: 'Citi', fn: citiScraper },
    { name: 'Capital One', fn: capitaloneScraper },
    { name: 'Discover', fn: discoverScraper },
    { name: 'Bank of America', fn: bofaScraper },
    { name: 'Wells Fargo', fn: wellsfargoScraper },
    { name: 'US Bank', fn: usbankScraper },
    { name: 'Other Issuers', fn: othersScraper },
  ];

  for (const scraper of scrapers) {
    console.log(`\n📋 Scraping ${scraper.name}...`);
    try {
      const cards = await scraper.fn();
      console.log(`   ✅ Found ${cards.length} cards from ${scraper.name}`);
      allCards.push(...cards);
    } catch (error) {
      console.error(`   ❌ Error scraping ${scraper.name}: ${error.message}`);
      errors.push({ issuer: scraper.name, error: error.message });
    }
  }

  // Validate all cards against iOS schema
  console.log('\n📋 Validating cards against iOS schema...');
  const validationResult = validateAllCards(allCards);
  printValidationSummary(validationResult);

  if (!validationResult.passed) {
    console.error('\n❌ Validation failed! Fix the errors above before uploading.');
    process.exit(1);
  }

  // Check for duplicate categories (warning only)
  const duplicateCategories = checkDuplicateCategories(allCards);

  // Validate image URLs
  const imageValidation = await validateImageUrls(allCards);

  // Save results
  const result = {
    scrapedAt: new Date().toISOString(),
    totalCards: allCards.length,
    errors: errors,
    duplicateCategories: duplicateCategories,
    imageValidation: {
      valid: imageValidation.valid,
      invalid: imageValidation.invalid,
      missing: imageValidation.missing,
      errors: imageValidation.errors
    },
    cards: allCards
  };

  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(result, null, 2));

  console.log('\n' + '='.repeat(50));
  console.log(`📊 Scraping Complete!`);
  console.log(`   Total cards: ${allCards.length}`);
  console.log(`   Valid cards: ${validationResult.validCards}`);
  console.log(`   Scraper errors: ${errors.length}`);
  console.log(`   Images: ${imageValidation.valid} valid, ${imageValidation.invalid} invalid, ${imageValidation.missing} missing`);
  console.log(`   Output saved to: ${OUTPUT_FILE}`);
  console.log('='.repeat(50));

  return result;
}

// Run if called directly
if (require.main === module) {
  runAllScrapers()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Fatal error:', error);
      process.exit(1);
    });
}

module.exports = { runAllScrapers };
