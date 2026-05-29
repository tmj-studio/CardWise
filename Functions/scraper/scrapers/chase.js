/**
 * Chase Credit Card Scraper
 * Uses HTTP requests to scrape real data from Chase website
 */

const https = require('https');
const { generateCardId, mapCategory } = require('../utils/categories');

// Fallback annual fees for cards where scraping fails
const KNOWN_ANNUAL_FEES = {
  'sapphire-preferred': 95,
  'sapphire-reserve': 795,
  'freedom-unlimited': 0,
  'freedom-flex': 0,
  'freedom-rise': 0,
  'freedom-student': 0,
  'ink-preferred': 95,
  'ink-cash': 0,
  'ink-unlimited': 0,
  'ink-premier': 195,
  'united-quest': 350,
  'marriott-bountiful': 250,
  'united-gateway': 0,
  'united-explorer': 150,  // After first year intro $0
  'united-club-infinite': 695,
  'southwest-priority': 229,
  'southwest-plus': 99,
  'southwest-premier': 149,
  'marriott-boundless': 95,
  'marriott-bold': 0,
  'ihg-premier': 99,
  'ihg-traveler': 0,
  'hyatt': 95,
  'amazon-prime': 0,
  'amazon-rewards': 0,
  'disney-visa': 0,
  'disney-premier': 49,
  'instacart': 0,
  'doordash': 0,
  'aeroplan': 95,
  'british-airways': 95,
};

// Chase card URLs - organized by product line
const CHASE_CARD_PAGES = [
  // Sapphire Series
  { slug: 'sapphire-preferred', url: 'https://creditcards.chase.com/rewards-credit-cards/sapphire/preferred', network: 'visa' },
  { slug: 'sapphire-reserve', url: 'https://creditcards.chase.com/rewards-credit-cards/sapphire/reserve', network: 'visa' },

  // Freedom Series
  { slug: 'freedom-unlimited', url: 'https://creditcards.chase.com/cash-back-credit-cards/freedom/unlimited', network: 'visa' },
  { slug: 'freedom-flex', url: 'https://creditcards.chase.com/cash-back-credit-cards/freedom/flex', network: 'mastercard' },
  { slug: 'freedom-rise', url: 'https://creditcards.chase.com/cash-back-credit-cards/freedom/rise', network: 'visa' },
  { slug: 'freedom-student', url: 'https://creditcards.chase.com/cash-back-credit-cards/freedom/student', network: 'visa' },

  // Ink Business Series
  { slug: 'ink-preferred', url: 'https://creditcards.chase.com/business-credit-cards/ink/business-preferred', network: 'visa' },
  { slug: 'ink-cash', url: 'https://creditcards.chase.com/business-credit-cards/ink/cash', network: 'visa' },
  { slug: 'ink-unlimited', url: 'https://creditcards.chase.com/business-credit-cards/ink/unlimited', network: 'visa' },
  { slug: 'ink-premier', url: 'https://creditcards.chase.com/business-credit-cards/ink/premier', network: 'visa' },

  // United Airlines
  { slug: 'united-quest', url: 'https://creditcards.chase.com/travel-credit-cards/united/united-quest', network: 'visa' },
  { slug: 'united-explorer', url: 'https://creditcards.chase.com/travel-credit-cards/united/united-explorer', network: 'visa' },
  { slug: 'united-gateway', url: 'https://creditcards.chase.com/travel-credit-cards/united/united-gateway', network: 'visa' },
  { slug: 'united-club-infinite', url: 'https://creditcards.chase.com/travel-credit-cards/united/club-infinite', network: 'visa' },

  // Southwest Airlines
  { slug: 'southwest-priority', url: 'https://creditcards.chase.com/travel-credit-cards/southwest/priority', network: 'visa' },
  { slug: 'southwest-plus', url: 'https://creditcards.chase.com/travel-credit-cards/southwest/plus', network: 'visa' },
  { slug: 'southwest-premier', url: 'https://creditcards.chase.com/travel-credit-cards/southwest/premier', network: 'visa' },

  // Marriott
  { slug: 'marriott-boundless', url: 'https://creditcards.chase.com/travel-credit-cards/marriott-bonvoy/boundless', network: 'visa' },
  { slug: 'marriott-bold', url: 'https://creditcards.chase.com/travel-credit-cards/marriott-bonvoy/bold', network: 'visa' },
  { slug: 'marriott-bountiful', url: 'https://creditcards.chase.com/travel-credit-cards/marriott-bonvoy/bountiful', network: 'visa' },

  // IHG (correct URLs)
  { slug: 'ihg-premier', url: 'https://creditcards.chase.com/travel-credit-cards/ihg-rewards-club/premier', network: 'mastercard' },
  { slug: 'ihg-traveler', url: 'https://creditcards.chase.com/travel-credit-cards/ihg-rewards-club/traveler', network: 'mastercard' },

  // World of Hyatt (correct URL)
  { slug: 'hyatt', url: 'https://creditcards.chase.com/travel-credit-cards/world-of-hyatt-credit-card', network: 'visa' },

  // Amazon
  { slug: 'amazon-prime', url: 'https://creditcards.chase.com/cash-back-credit-cards/amazon-prime-rewards', network: 'visa' },
  { slug: 'amazon-rewards', url: 'https://creditcards.chase.com/cash-back-credit-cards/amazon-rewards', network: 'visa' },

  // Disney (correct URLs)
  { slug: 'disney-visa', url: 'https://creditcards.chase.com/rewards-credit-cards/disney/rewards', network: 'visa' },
  { slug: 'disney-premier', url: 'https://creditcards.chase.com/rewards-credit-cards/disney/premier', network: 'visa' },

  // Other Partners (correct URLs)
  { slug: 'instacart', url: 'https://creditcards.chase.com/cash-back-credit-cards/instacart', network: 'mastercard' },
  { slug: 'doordash', url: 'https://creditcards.chase.com/cash-back-credit-cards/doordash', network: 'mastercard' },
  { slug: 'aeroplan', url: 'https://creditcards.chase.com/travel-credit-cards/aircanada/aeroplan', network: 'visa' },
  { slug: 'british-airways', url: 'https://creditcards.chase.com/travel-credit-cards/avios/british-airways', network: 'visa' }
];

/**
 * Fetch a URL with proper headers
 */
function fetchPage(url) {
  return new Promise((resolve, reject) => {
    const options = {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'identity',
        'Connection': 'keep-alive'
      },
      timeout: 15000
    };

    const req = https.get(url, options, (res) => {
      // Handle redirects
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        const redirectUrl = res.headers.location.startsWith('http')
          ? res.headers.location
          : new URL(res.headers.location, url).href;
        return fetchPage(redirectUrl).then(resolve).catch(reject);
      }

      if (res.statusCode !== 200) {
        reject(new Error(`HTTP ${res.statusCode}`));
        return;
      }

      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(data));
    });

    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Timeout')); });
  });
}

/**
 * Extract card name from HTML
 */
function extractCardName(html) {
  // Try to find card name in h1 (may contain <sup> tags)
  const h1Match = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
  if (h1Match) {
    // Remove all HTML tags and clean up
    let name = h1Match[1]
      .replace(/<[^>]+>/g, '')  // Remove HTML tags
      .replace(/®|™|℠|SM/g, '') // Remove trademark symbols including SM
      .replace(/Credit Card/i, '')  // Remove "Credit Card"
      .replace(/^The\s+New\s+/i, '') // Remove "The New " prefix
      .replace(/\s+/g, ' ')      // Normalize whitespace
      .trim();

    // Make sure name starts with issuer name if not present
    if (name && !name.toLowerCase().includes('chase') && !name.toLowerCase().includes('ink')) {
      // Check if it's a co-brand card
      if (!name.toLowerCase().match(/^(united|southwest|marriott|ihg|hyatt|amazon|disney|doordash|instacart|aeroplan|british|prime|world of)/i)) {
        name = 'Chase ' + name;
      }
    }

    // Special card name fixes
    if (name === 'Chase New to Credit') {
      name = 'Chase Freedom Student';
    }

    return name;
  }

  // Fallback to title
  const titleMatch = html.match(/<title>([^<|]+)/i);
  if (titleMatch) {
    return titleMatch[1]
      .replace(/®|™|℠|SM/g, '')
      .replace(/\s*\|\s*Chase.*$/gi, '')
      .replace(/Credit Card/i, '')
      .replace(/^The\s+New\s+/i, '')
      .trim();
  }

  return null;
}

/**
 * Extract annual fee from HTML
 */
function extractAnnualFee(html) {
  // Look for ANNUAL FEE section followed by dollar amount (most common Chase pattern)
  const sectionMatch = html.match(/ANNUAL\s*FEE<\/h\d>\s*<p>\$(\d+)/i);
  if (sectionMatch) {
    return parseInt(sectionMatch[1], 10);
  }

  // Look for "$0 intro annual fee for the first year, then $X" pattern (United Explorer style)
  const introFeeMatch = html.match(/\$0\s*intro\s*annual\s*fee[^,]*,\s*then\s*\$(\d+)/i);
  if (introFeeMatch) {
    return parseInt(introFeeMatch[1], 10);
  }

  // Look for "$X annual fee" in content (not in nav links)
  // Match only in paragraph or div content, not in links
  const contentFeeMatch = html.match(/<p[^>]*>\s*\$(\d+)\s*annual\s*fee/i);
  if (contentFeeMatch) {
    return parseInt(contentFeeMatch[1], 10);
  }

  // Look for just the fee amount after heading
  const headingMatch = html.match(/>\s*ANNUAL\s*FEE\s*<[^>]*>\s*<[^>]*>\s*\$(\d+)/i);
  if (headingMatch) {
    return parseInt(headingMatch[1], 10);
  }

  // Check for $0 annual fee in actual content (not nav)
  const zeroFeeMatch = html.match(/<p[^>]*>[^<]*\$0\s*annual\s*fee/i);
  if (zeroFeeMatch) {
    return 0;
  }

  // Look for "no annual fee" badge or text in content
  if (html.match(/class="[^"]*no-annual-fee[^"]*"/i)) {
    return 0;
  }

  return null;
}

/**
 * Extract and normalize rewards from HTML
 */
function extractRewards(html) {
  const rewards = [];
  const seen = new Set();

  // Patterns to match rewards - more comprehensive
  const patterns = [
    // "5x on travel" or "5X total points on travel"
    { regex: /(\d+)[xX]\s*(?:total\s*)?(?:points?\s*)?(?:on|at)\s+([^<,.\n]{3,50})/gi, isPercentage: false },
    // "5% cash back on travel"
    { regex: /(\d+)%\s*(?:cash\s*back\s*)?(?:on|at)\s+([^<,.\n]{3,50})/gi, isPercentage: true },
    // "Earn 5x on travel"
    { regex: /earn\s+(\d+)[xX]\s*(?:total\s*)?(?:points?\s*)?(?:on|at)\s+([^<,.\n]{3,50})/gi, isPercentage: false },
    // "Earn 5% on travel"
    { regex: /earn\s+(\d+)%\s*(?:cash\s*back\s*)?(?:on|at)\s+([^<,.\n]{3,50})/gi, isPercentage: true },
    // "5X points per $1 spent at/on/when" - co-brand style
    { regex: /(\d+)[xX]\s*(?:total\s*)?points?\s*(?:per\s*\$1\s*)?(?:spent\s*)?(?:at|on|when\s*you\s*\w+\s*at)\s+([^<,.\n]{3,50})/gi, isPercentage: false },
    // "5x miles on" - for airline cards
    { regex: /(\d+)[xX]\s*(?:total\s*)?miles?\s*(?:on|at|for)\s+([^<,.\n]{3,50})/gi, isPercentage: false },
    // "That's Xx points" in benefit descriptions
    { regex: /that's\s*<b>(\d+)[xX]\s*points?<\/b>\s*(?:on|at|with)?\s*([^<\n]{3,50})?/gi, isPercentage: false }
  ];

  for (const { regex, isPercentage } of patterns) {
    let match;
    while ((match = regex.exec(html)) !== null) {
      const multiplier = parseInt(match[1], 10);
      let rawCategory = (match[2] || '')
        .replace(/<[^>]+>/g, '')
        .replace(/&[^;]+;/g, ' ')
        .replace(/\s+/g, ' ')
        .trim()
        .toLowerCase();

      // Skip invalid multipliers
      if (multiplier < 1 || multiplier > 30) continue;

      // Skip if category is empty or too short
      if (rawCategory.length < 3) continue;

      // Clean up category text and map to standard categories
      const categoryInfo = mapRawCategory(rawCategory, multiplier);
      if (categoryInfo) {
        // Allow duplicates if they have notes (portal-specific rewards)
        // Otherwise skip duplicates
        const key = categoryInfo.note
          ? `${categoryInfo.category}:${categoryInfo.note}`
          : categoryInfo.category;

        if (!seen.has(key)) {
          seen.add(key);
          rewards.push({
            category: categoryInfo.category,
            multiplier: multiplier,
            isPercentage: isPercentage,
            cap: categoryInfo.cap || null,
            capPeriod: categoryInfo.capPeriod || null,
            note: categoryInfo.note || null
          });
        }
      }
    }
  }

  return rewards;
}

/**
 * Map raw category text to standard category
 */
function mapRawCategory(rawCategory, multiplier) {
  const text = rawCategory.toLowerCase();

  // Skip "this card" patterns
  if (text.includes('this card') || text.includes('with this')) {
    return null;
  }

  // Travel portal - use 'travel' with note to distinguish from general travel
  if (text.includes('chase travel') || text.includes('chase ultimaterewards') || text.includes('ultimate rewards')) {
    return { category: 'travel', note: 'Booked through Chase Travel' };
  }

  // Specific airlines/hotels (co-brand)
  if (text.includes('united') && !text.includes('united states')) return { category: 'airlines', note: 'United purchases' };
  if (text.includes('southwest')) return { category: 'airlines', note: 'Southwest purchases' };
  if (text.includes('aeroplan') || text.includes('air canada')) return { category: 'airlines', note: 'Air Canada/Aeroplan purchases' };
  if (text.includes('british airways') || text.includes('avios')) return { category: 'airlines', note: 'British Airways purchases' };

  // Hotels
  if (text.includes('marriott') || text.includes('bonvoy')) return { category: 'hotels', note: 'Marriott Bonvoy purchases' };
  if (text.includes('ihg') || text.includes('intercontinental')) return { category: 'hotels', note: 'IHG Hotels purchases' };
  if (text.includes('hyatt')) return { category: 'hotels', note: 'Hyatt purchases' };

  // Dining
  if (text.includes('dining') || text.includes('restaurant') || text.includes('takeout') || text.includes('delivery service')) {
    return { category: 'dining' };
  }

  // Drugstore
  if (text.includes('drugstore') || text.includes('pharmacy')) {
    return { category: 'drugstore' };
  }

  // Gas
  if (text.includes('gas station') || text.match(/\bgas\b/)) {
    return { category: 'gas' };
  }

  // Grocery
  if (text.includes('grocery') || text.includes('supermarket') || text.includes('instacart')) {
    return { category: 'grocery' };
  }

  // Streaming
  if (text.includes('streaming')) {
    return { category: 'streaming' };
  }

  // Travel (general) - be careful not to match "travel purchased through chase travel"
  if ((text.includes('travel') && !text.includes('chase travel')) || text.includes('hotel') || text.includes('flight') || text.includes('airline')) {
    return { category: 'travel' };
  }

  // Lyft
  if (text.includes('lyft')) {
    return { category: 'lyft', note: 'Lyft rides' };
  }

  // Transit
  if (text.includes('transit') || text.includes('commuting')) {
    return { category: 'transit' };
  }

  // Online shopping
  if (text.includes('online') && (text.includes('shopping') || text.includes('purchase'))) {
    return { category: 'onlineShopping' };
  }

  // Amazon
  if (text.includes('amazon') || text.includes('whole foods')) {
    return { category: 'amazon', note: 'Amazon purchases' };
  }

  // Disney
  if (text.includes('disney')) {
    return { category: 'disney', note: 'Disney purchases' };
  }

  // DoorDash/food delivery
  if (text.includes('doordash') || text.includes('food delivery')) {
    return { category: 'dining', note: 'DoorDash/delivery purchases' };
  }

  // All other purchases (base rate)
  if (text.includes('all other') || text.includes('everything else') || text.includes('other purchases')) {
    return null; // This is the base rate, not a category bonus
  }

  // Business categories
  if (text.includes('shipping')) return { category: 'shipping' };
  if (text.includes('internet') || text.includes('cable') || text.includes('phone service')) return { category: 'internet' };
  if (text.includes('advertising') || text.includes('social media')) return { category: 'advertising' };
  if (text.includes('office supply') || text.includes('office supplies')) return { category: 'officeSupplies' };

  return null;
}

/**
 * Extract card image URL
 */
function extractImageUrl(html, baseUrl) {
  const patterns = [
    /src=["']([^"']*card-art[^"']*\.png)/i,
    /src=["']([^"']*card[^"']*\.png)/i,
    /src=["']([^"']*sapphire[^"']*\.png)/i,
    /src=["']([^"']*freedom[^"']*\.png)/i,
    /src=["']([^"']*ink[^"']*\.png)/i
  ];

  for (const pattern of patterns) {
    const match = html.match(pattern);
    if (match) {
      let imgUrl = match[1];
      if (!imgUrl.startsWith('http')) {
        imgUrl = new URL(imgUrl, baseUrl).href;
      }
      return imgUrl;
    }
  }

  return null;
}

/**
 * Extract rotating categories (for Freedom Flex)
 */
function extractRotatingCategories(html, cardName) {
  if (cardName && cardName.toLowerCase().includes('freedom flex')) {
    // Freedom Flex has rotating 5% categories
    const currentQuarter = Math.floor((new Date().getMonth()) / 3) + 1;
    const currentYear = new Date().getFullYear();

    // Q4 2024/Q1 2025 typically: Amazon, Target, Walmart.com
    // Categories vary by quarter
    const quarterlyCategories = {
      1: ['grocery', 'fitness'],
      2: ['gas', 'homeImprovement'],
      3: ['dining', 'drugstore'],
      4: ['amazon', 'target', 'walmart']
    };

    return {
      quarter: currentQuarter,
      year: currentYear,
      categories: quarterlyCategories[currentQuarter] || ['grocery', 'gas'],
      multiplier: 5,
      isPercentage: true,
      cap: 1500,
      capPeriod: 'quarterly',
      activationRequired: true
    };
  }
  return null;
}

/**
 * Determine base reward rate from card type
 */
function getBaseReward(html, cardName) {
  const text = html.toLowerCase();

  // Look for explicit base rate mentions
  const baseMatch = text.match(/(\d+(?:\.\d+)?)[%x]\s*(?:cash\s*back\s*)?on\s*(?:all\s*)?other\s*(?:purchases|everything)/i);
  if (baseMatch) {
    return parseFloat(baseMatch[1]);
  }

  // Card-specific defaults
  if (cardName) {
    const name = cardName.toLowerCase();
    if (name.includes('freedom unlimited')) return 1.5;
    if (name.includes('freedom rise')) return 1.5;
    if (name.includes('ink unlimited')) return 1.5;
  }

  return 1; // Default base reward
}

/**
 * Determine reward type from card name/content
 */
function getRewardType(cardName, html) {
  const name = (cardName || '').toLowerCase();
  const text = html.toLowerCase();

  if (name.includes('freedom') || text.includes('cash back')) {
    return 'cashback';
  }
  if (name.includes('united') || name.includes('southwest') || name.includes('british airways') || name.includes('aeroplan')) {
    return 'miles';
  }
  return 'points';
}

/**
 * Scrape a single Chase card page
 */
async function scrapeCard(cardInfo) {
  try {
    const html = await fetchPage(cardInfo.url);

    const name = extractCardName(html);
    if (!name) {
      console.log(`    ⚠️ Could not extract card name from ${cardInfo.slug}`);
      return null;
    }

    let annualFee = extractAnnualFee(html);
    
    // Use fallback if annual fee couldn't be scraped
    if (annualFee === null && Object.prototype.hasOwnProperty.call(KNOWN_ANNUAL_FEES, cardInfo.slug)) {
      console.log(`    ℹ️ Using fallback annual fee for ${cardInfo.slug}: $${KNOWN_ANNUAL_FEES[cardInfo.slug]}`);
      annualFee = KNOWN_ANNUAL_FEES[cardInfo.slug];
    }
    
    const rewards = extractRewards(html);
    const imageURL = extractImageUrl(html, cardInfo.url);
    const rotating = extractRotatingCategories(html, name);
    const baseReward = getBaseReward(html, name);
    const rewardType = getRewardType(name, html);

    // Map rewards to iOS format (keep note for portal-specific rewards)
    const categoryRewards = rewards
      .map(r => {
        const mappedCategory = mapCategory(r.category);
        if (!mappedCategory) return null;
        return {
          category: mappedCategory,
          multiplier: r.multiplier,
          isPercentage: r.isPercentage || rewardType === 'cashback',
          cap: r.cap,
          capPeriod: r.capPeriod,
          note: r.note || null
        };
      })
      .filter(Boolean);

    return {
      id: generateCardId('Chase', name),
      name: name,
      issuer: 'Chase',
      network: cardInfo.network,
      annualFee: annualFee,
      rewardType: rewardType,
      baseReward: baseReward,
      baseIsPercentage: rewardType === 'cashback',
      categoryRewards: categoryRewards,
      rotatingCategories: rotating ? [rotating] : null,
      selectableConfig: null,
      signUpBonus: null,
      imageColor: '#003B73',
      imageURL: imageURL
    };
  } catch (error) {
    console.log(`    ⚠️ Failed to scrape ${cardInfo.slug}: ${error.message}`);
    return null;
  }
}

/**
 * Main scrape function
 */
async function scrapeChase() {
  console.log('🏦 Chase: Scraping credit cards...');

  const cards = [];
  let successCount = 0;
  let failCount = 0;

  for (const cardInfo of CHASE_CARD_PAGES) {
    console.log(`  📋 Scraping ${cardInfo.slug}...`);

    const card = await scrapeCard(cardInfo);
    if (card) {
      cards.push(card);
      successCount++;
      console.log(`    ✅ ${card.name} - $${card.annualFee} annual fee, ${card.categoryRewards.length} categories`);
    } else {
      failCount++;
    }

    // Polite delay between requests
    await new Promise(r => setTimeout(r, 500 + Math.random() * 500));
  }

  console.log(`  📊 Chase: ${successCount} succeeded, ${failCount} failed`);

  // If we got too few cards, something is wrong - use fallback
  if (cards.length < 10) {
    console.log('  ⚠️ Too few cards scraped, using fallback data');
    return getFallbackCards();
  }

  return cards;
}

/**
 * Fallback card data for when scraping fails
 */
function getFallbackCards() {
  // Minimal fallback - just the most important cards
  const fallback = [
    {
      name: 'Chase Sapphire Preferred',
      annualFee: 95,
      rewardType: 'points',
      network: 'visa',
      baseReward: 1,
      categories: [
        { category: 'travelPortal', multiplier: 5 },
        { category: 'dining', multiplier: 3 },
        { category: 'streaming', multiplier: 3 },
        { category: 'travel', multiplier: 2 }
      ],
      imageURL: 'https://creditcards.chase.com/content/dam/jpmc-marketplace/card-art/sapphire_preferred_card.png'
    },
    {
      name: 'Chase Sapphire Reserve',
      annualFee: 795,
      rewardType: 'points',
      network: 'visa',
      baseReward: 1,
      categories: [
        { category: 'travelPortal', multiplier: 8 },
        { category: 'dining', multiplier: 3 },
        { category: 'travel', multiplier: 3 }
      ],
      imageURL: 'https://creditcards.chase.com/content/dam/jpmc-marketplace/card-art/sapphire_reserve_card_Halo.png'
    },
    {
      name: 'Chase Freedom Unlimited',
      annualFee: 0,
      rewardType: 'cashback',
      network: 'visa',
      baseReward: 1.5,
      categories: [
        { category: 'travelPortal', multiplier: 5 },
        { category: 'dining', multiplier: 3 },
        { category: 'drugstore', multiplier: 3 }
      ],
      imageURL: 'https://creditcards.chase.com/content/dam/jpmc-marketplace/card-art/freedom_unlimited_card_alt.png'
    },
    {
      name: 'Chase Freedom Flex',
      annualFee: 0,
      rewardType: 'cashback',
      network: 'mastercard',
      baseReward: 1,
      categories: [
        { category: 'travelPortal', multiplier: 5 },
        { category: 'dining', multiplier: 3 },
        { category: 'drugstore', multiplier: 3 }
      ],
      rotating: { multiplier: 5, cap: 1500, capPeriod: 'quarterly', activationRequired: true },
      imageURL: 'https://creditcards.chase.com/content/dam/jpmc-marketplace/card-art/freedom_flex_card_alt.png'
    }
  ];

  return fallback.map(card => {
    const categoryRewards = (card.categories || []).map(c => ({
      category: mapCategory(c.category),
      multiplier: c.multiplier,
      isPercentage: card.rewardType === 'cashback',
      cap: c.cap || null,
      capPeriod: c.capPeriod || null
    })).filter(c => c.category);

    return {
      id: generateCardId('Chase', card.name),
      name: card.name,
      issuer: 'Chase',
      network: card.network,
      annualFee: card.annualFee,
      rewardType: card.rewardType,
      baseReward: card.baseReward,
      baseIsPercentage: card.rewardType === 'cashback',
      categoryRewards: categoryRewards,
      rotatingCategories: card.rotating ? [card.rotating] : null,
      selectableConfig: null,
      signUpBonus: null,
      imageColor: '#003B73',
      imageURL: card.imageURL
    };
  });
}

// Run standalone for testing
if (require.main === module) {
  console.log('🧪 Testing Chase Scraper...\n');
  scrapeChase()
    .then(cards => {
      console.log(`\n✅ Total cards: ${cards.length}`);
      cards.forEach(card => {
        console.log(`  - ${card.name}: $${card.annualFee} annual fee, ${card.categoryRewards.length} categories`);
      });
    })
    .catch(err => {
      console.error('❌ Error:', err.message);
      process.exit(1);
    });
}

module.exports = scrapeChase;
