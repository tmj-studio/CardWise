/**
 * Credit Card Data Validation Script
 *
 * Validates all card data against the iOS CreditCard schema
 * to ensure compatibility with the CardWise iOS app.
 */

const fs = require('fs');
const path = require('path');
const { getValidCategories } = require('./utils/categories');
const { validateAllCards, printValidationSummary } = require('./utils/schema-validator');

// Import scrapers
const scrapeChase = require('./scrapers/chase');
const scrapeAmex = require('./scrapers/amex');
const scrapeCiti = require('./scrapers/citi');
const scrapeCapitalOne = require('./scrapers/capitalone');
const scrapeDiscover = require('./scrapers/discover');
const scrapeWellsFargo = require('./scrapers/wellsfargo');
const scrapeBofa = require('./scrapers/bofa');
const scrapeUsBank = require('./scrapers/usbank');
const scrapeOthers = require('./scrapers/others');

/**
 * Get all cards from all scrapers
 */
async function getAllCards() {
  const results = await Promise.all([
    scrapeChase(),
    scrapeAmex(),
    scrapeCiti(),
    scrapeCapitalOne(),
    scrapeDiscover(),
    scrapeWellsFargo(),
    scrapeBofa(),
    scrapeUsBank(),
    scrapeOthers()
  ]);

  return results.flat();
}

/**
 * Validate cards from scrapers (live data)
 */
async function validateFromScrapers() {
  console.log('🔍 Validating card data from scrapers...\n');

  try {
    const allCards = await getAllCards();
    console.log(`📊 Total cards from scrapers: ${allCards.length}\n`);

    // Run iOS schema validation
    const result = validateAllCards(allCards);
    printValidationSummary(result);

    // Additional quality checks
    runQualityChecks(allCards);

    return result;
  } catch (error) {
    console.error('❌ Error running scrapers:', error.message);
    process.exit(1);
  }
}

/**
 * Validate cards from scraped-cards.json file
 */
function validateFromFile() {
  const filePath = path.join(__dirname, 'scraped-cards.json');

  if (!fs.existsSync(filePath)) {
    console.error('❌ scraped-cards.json not found. Run the scraper first.');
    process.exit(1);
  }

  console.log('🔍 Validating card data from scraped-cards.json...\n');

  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  console.log(`📊 Total cards in file: ${data.cards.length}`);
  console.log(`📅 Scraped at: ${data.scrapedAt}\n`);

  // Run iOS schema validation
  const result = validateAllCards(data.cards);
  printValidationSummary(result);

  // Additional quality checks
  runQualityChecks(data.cards);

  return result;
}

/**
 * Run additional quality checks
 */
function runQualityChecks(cards) {
  console.log('\n📋 Additional Quality Checks:');
  console.log('─'.repeat(40));

  // Check for missing images
  const missingImages = cards.filter(c => !c.imageURL);
  if (missingImages.length > 0) {
    console.log(`\n⚠️  Cards missing images (${missingImages.length}):`);
    missingImages.forEach(card => {
      console.log(`   - ${card.issuer}: ${card.name}`);
    });
  } else {
    console.log('✅ All cards have images');
  }

  // Check for cards with no rewards
  const noRewardsCards = cards.filter(c =>
    c.categoryRewards.length === 0 &&
    c.baseReward <= 1 &&
    !c.rotatingCategories &&
    !c.selectableConfig
  );
  // Filter out expected no-rewards cards
  const expectedNoRewards = [
    'Citi Diamond Preferred',
    'Capital One Platinum',
    'Wells Fargo Reflect',
    'Target RedCard Credit',
    'Chase Freedom Student'
  ];
  const unexpectedNoRewards = noRewardsCards.filter(c => !expectedNoRewards.includes(c.name));
  if (unexpectedNoRewards.length > 0) {
    console.log(`\n⚠️  Cards with no reward categories (${unexpectedNoRewards.length}):`);
    unexpectedNoRewards.forEach(card => {
      console.log(`   - ${card.issuer}: ${card.name}`);
    });
  } else {
    console.log('✅ All cards have expected rewards');
  }

  // Print category statistics
  console.log('\n📈 Top 15 Categories by Card Count:');
  const categoryCount = {};
  cards.forEach(card => {
    card.categoryRewards.forEach(r => {
      categoryCount[r.category] = (categoryCount[r.category] || 0) + 1;
    });
  });
  const sortedCategories = Object.entries(categoryCount)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 15);
  sortedCategories.forEach(([cat, count]) => {
    console.log(`   ${cat}: ${count} cards`);
  });

  // Print valid iOS categories for reference
  console.log('\n📱 Valid iOS SpendingCategory values:');
  const validCats = getValidCategories();
  console.log(`   ${validCats.join(', ')}`);
}

// Main execution
async function main() {
  const args = process.argv.slice(2);

  if (args.includes('--file') || args.includes('-f')) {
    // Validate from scraped-cards.json
    const result = validateFromFile();
    process.exit(result.passed ? 0 : 1);
  } else {
    // Validate from scrapers (default)
    const result = await validateFromScrapers();
    process.exit(result.passed ? 0 : 1);
  }
}

main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
