import Foundation

struct Merchant: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let category: SpendingCategory
    let alternativeCategories: [SpendingCategory]?
    let keywords: [String]?       // for search matching

    init(name: String, category: SpendingCategory, alternativeCategories: [SpendingCategory]? = nil, keywords: [String]? = nil) {
        self.id = UUID().uuidString
        self.name = name
        self.category = category
        self.alternativeCategories = alternativeCategories
        self.keywords = keywords
    }
}

// Common merchant database
struct MerchantDatabase {
    static let merchants: [Merchant] = [
        // Superstore (NOT grocery for most cards like Amex Gold)
        Merchant(name: "Walmart", category: .other, alternativeCategories: [.grocery], keywords: ["walmart", "wal-mart"]),
        Merchant(name: "Target", category: .other, alternativeCategories: [.grocery], keywords: ["target"]),
        Merchant(name: "Costco", category: .wholesale, keywords: ["costco"]),
        Merchant(name: "Sam's Club", category: .wholesale, keywords: ["sams", "sam's"]),
        Merchant(name: "BJ's Wholesale", category: .wholesale, keywords: ["bj's", "bjs"]),
        Merchant(name: "Kroger", category: .grocery, keywords: ["kroger"]),
        Merchant(name: "Whole Foods", category: .grocery, keywords: ["whole foods", "wholefoods"]),
        Merchant(name: "Trader Joe's", category: .grocery, keywords: ["trader joe", "trader joes"]),
        Merchant(name: "Safeway", category: .grocery, keywords: ["safeway"]),
        Merchant(name: "Publix", category: .grocery, keywords: ["publix"]),
        Merchant(name: "Albertsons", category: .grocery, keywords: ["albertsons"]),
        Merchant(name: "Aldi", category: .grocery, keywords: ["aldi"]),
        Merchant(name: "H-E-B", category: .grocery, keywords: ["heb", "h-e-b"]),
        Merchant(name: "Wegmans", category: .grocery, keywords: ["wegmans"]),
        Merchant(name: "Food Lion", category: .grocery, keywords: ["food lion"]),
        Merchant(name: "Sprouts", category: .grocery, keywords: ["sprouts"]),
        Merchant(name: "Vons", category: .grocery, keywords: ["vons"]),
        Merchant(name: "Harris Teeter", category: .grocery, keywords: ["harris teeter"]),
        Merchant(name: "Giant", category: .grocery, keywords: ["giant"]),
        Merchant(name: "Stop & Shop", category: .grocery, keywords: ["stop & shop", "stop and shop"]),
        Merchant(name: "Meijer", category: .grocery, keywords: ["meijer"]),
        Merchant(name: "Instacart", category: .grocery, keywords: ["instacart"]),

        // Gas
        Merchant(name: "Shell", category: .gas, keywords: ["shell"]),
        Merchant(name: "Chevron", category: .gas, keywords: ["chevron"]),
        Merchant(name: "ExxonMobil", category: .gas, keywords: ["exxon", "mobil"]),
        Merchant(name: "BP", category: .gas, keywords: ["bp"]),
        Merchant(name: "Costco Gas", category: .gas, keywords: ["costco gas"]),
        Merchant(name: "76", category: .gas, keywords: ["76 gas"]),
        Merchant(name: "Arco", category: .gas, keywords: ["arco"]),
        Merchant(name: "Sunoco", category: .gas, keywords: ["sunoco"]),
        Merchant(name: "Marathon", category: .gas, keywords: ["marathon"]),
        Merchant(name: "Wawa", category: .gas, keywords: ["wawa"]),
        Merchant(name: "Sheetz", category: .gas, keywords: ["sheetz"]),
        Merchant(name: "QuikTrip", category: .gas, keywords: ["quiktrip", "qt"]),
        Merchant(name: "Circle K", category: .gas, keywords: ["circle k"]),
        Merchant(name: "7-Eleven", category: .gas, keywords: ["7-eleven", "7 eleven"]),
        Merchant(name: "GetGo", category: .gas, keywords: ["getgo"]),
        Merchant(name: "Speedway", category: .gas, keywords: ["speedway"]),
        Merchant(name: "ChargePoint", category: .gas, keywords: ["chargepoint", "ev charging"]),
        Merchant(name: "Tesla Supercharger", category: .gas, keywords: ["tesla", "supercharger"]),
        Merchant(name: "Electrify America", category: .gas, keywords: ["electrify america"]),

        // Dining - Fast Food
        Merchant(name: "Starbucks", category: .dining, keywords: ["starbucks"]),
        Merchant(name: "McDonald's", category: .dining, keywords: ["mcdonalds", "mcdonald's"]),
        Merchant(name: "Chipotle", category: .dining, keywords: ["chipotle"]),
        Merchant(name: "Chick-fil-A", category: .dining, keywords: ["chick-fil-a", "chickfila"]),
        Merchant(name: "Wendy's", category: .dining, keywords: ["wendys", "wendy's"]),
        Merchant(name: "Burger King", category: .dining, keywords: ["burger king"]),
        Merchant(name: "Taco Bell", category: .dining, keywords: ["taco bell"]),
        Merchant(name: "Subway", category: .dining, keywords: ["subway"]),
        Merchant(name: "Panda Express", category: .dining, keywords: ["panda express"]),
        Merchant(name: "Five Guys", category: .dining, keywords: ["five guys"]),
        Merchant(name: "In-N-Out", category: .dining, keywords: ["in-n-out", "in n out"]),
        Merchant(name: "Shake Shack", category: .dining, keywords: ["shake shack"]),
        Merchant(name: "Popeyes", category: .dining, keywords: ["popeyes"]),
        Merchant(name: "KFC", category: .dining, keywords: ["kfc", "kentucky fried"]),
        Merchant(name: "Dunkin'", category: .dining, keywords: ["dunkin", "dunkin donuts"]),
        Merchant(name: "Panera Bread", category: .dining, keywords: ["panera"]),
        Merchant(name: "Domino's", category: .dining, keywords: ["dominos", "domino's"]),
        Merchant(name: "Pizza Hut", category: .dining, keywords: ["pizza hut"]),
        Merchant(name: "Papa John's", category: .dining, keywords: ["papa johns", "papa john's"]),
        Merchant(name: "Sonic", category: .dining, keywords: ["sonic"]),
        Merchant(name: "Arby's", category: .dining, keywords: ["arbys", "arby's"]),
        Merchant(name: "Jack in the Box", category: .dining, keywords: ["jack in the box"]),
        Merchant(name: "Whataburger", category: .dining, keywords: ["whataburger"]),
        Merchant(name: "Wingstop", category: .dining, keywords: ["wingstop"]),
        Merchant(name: "Buffalo Wild Wings", category: .dining, keywords: ["buffalo wild wings", "bww"]),

        // Dining - Casual/Sit-down
        Merchant(name: "Applebee's", category: .dining, keywords: ["applebees", "applebee's"]),
        Merchant(name: "Chili's", category: .dining, keywords: ["chilis", "chili's"]),
        Merchant(name: "Olive Garden", category: .dining, keywords: ["olive garden"]),
        Merchant(name: "Red Lobster", category: .dining, keywords: ["red lobster"]),
        Merchant(name: "Outback Steakhouse", category: .dining, keywords: ["outback"]),
        Merchant(name: "Texas Roadhouse", category: .dining, keywords: ["texas roadhouse"]),
        Merchant(name: "Cheesecake Factory", category: .dining, keywords: ["cheesecake factory"]),
        Merchant(name: "TGI Friday's", category: .dining, keywords: ["tgi fridays", "fridays"]),
        Merchant(name: "IHOP", category: .dining, keywords: ["ihop"]),
        Merchant(name: "Denny's", category: .dining, keywords: ["dennys", "denny's"]),
        Merchant(name: "Cracker Barrel", category: .dining, keywords: ["cracker barrel"]),
        Merchant(name: "P.F. Chang's", category: .dining, keywords: ["pf changs", "p.f. chang's"]),

        // Dining - Delivery
        Merchant(name: "DoorDash", category: .dining, keywords: ["doordash"]),
        Merchant(name: "Uber Eats", category: .dining, keywords: ["uber eats", "ubereats"]),
        Merchant(name: "Grubhub", category: .dining, keywords: ["grubhub"]),
        Merchant(name: "Postmates", category: .dining, keywords: ["postmates"]),
        Merchant(name: "Seamless", category: .dining, keywords: ["seamless"]),
        Merchant(name: "Caviar", category: .dining, keywords: ["caviar"]),

        // Streaming
        Merchant(name: "Netflix", category: .streaming, keywords: ["netflix"]),
        Merchant(name: "Spotify", category: .streaming, keywords: ["spotify"]),
        Merchant(name: "Disney+", category: .streaming, keywords: ["disney+", "disney plus"]),
        Merchant(name: "HBO Max", category: .streaming, keywords: ["hbo", "max"]),
        Merchant(name: "YouTube Premium", category: .streaming, keywords: ["youtube"]),
        Merchant(name: "Apple TV+", category: .streaming, keywords: ["apple tv"]),
        Merchant(name: "Amazon Prime Video", category: .streaming, keywords: ["prime video"]),
        Merchant(name: "Hulu", category: .streaming, keywords: ["hulu"]),
        Merchant(name: "Peacock", category: .streaming, keywords: ["peacock"]),
        Merchant(name: "Paramount+", category: .streaming, keywords: ["paramount+"]),
        Merchant(name: "Apple Music", category: .streaming, keywords: ["apple music"]),
        Merchant(name: "Amazon Music", category: .streaming, keywords: ["amazon music"]),
        Merchant(name: "SiriusXM", category: .streaming, keywords: ["siriusxm", "sirius"]),
        Merchant(name: "Audible", category: .streaming, keywords: ["audible"]),
        Merchant(name: "Kindle Unlimited", category: .streaming, keywords: ["kindle unlimited"]),

        // Online Shopping
        Merchant(name: "Amazon", category: .amazon, alternativeCategories: [.onlineShopping], keywords: ["amazon"]),
        Merchant(name: "eBay", category: .onlineShopping, keywords: ["ebay"]),
        Merchant(name: "Etsy", category: .onlineShopping, keywords: ["etsy"]),
        Merchant(name: "Wayfair", category: .onlineShopping, keywords: ["wayfair"]),
        Merchant(name: "Newegg", category: .onlineShopping, keywords: ["newegg"]),
        Merchant(name: "Best Buy", category: .onlineShopping, keywords: ["best buy", "bestbuy"]),
        Merchant(name: "Apple Store", category: .onlineShopping, keywords: ["apple store", "apple.com"]),
        Merchant(name: "Nike", category: .onlineShopping, keywords: ["nike"]),
        Merchant(name: "Adidas", category: .onlineShopping, keywords: ["adidas"]),
        Merchant(name: "Zappos", category: .onlineShopping, keywords: ["zappos"]),
        Merchant(name: "Nordstrom", category: .onlineShopping, keywords: ["nordstrom"]),
        Merchant(name: "Macy's", category: .onlineShopping, keywords: ["macys", "macy's"]),
        Merchant(name: "Walmart.com", category: .onlineShopping, keywords: ["walmart.com"]),
        Merchant(name: "Target.com", category: .onlineShopping, keywords: ["target.com"]),
        Merchant(name: "SHEIN", category: .onlineShopping, keywords: ["shein"]),
        Merchant(name: "Temu", category: .onlineShopping, keywords: ["temu"]),
        Merchant(name: "AliExpress", category: .onlineShopping, keywords: ["aliexpress"]),

        // Travel - Airlines
        Merchant(name: "United Airlines", category: .travel, keywords: ["united"]),
        Merchant(name: "Delta", category: .travel, keywords: ["delta"]),
        Merchant(name: "American Airlines", category: .travel, keywords: ["american airlines", "aa"]),
        Merchant(name: "Southwest", category: .travel, keywords: ["southwest"]),
        Merchant(name: "JetBlue", category: .travel, keywords: ["jetblue"]),
        Merchant(name: "Alaska Airlines", category: .travel, keywords: ["alaska airlines"]),
        Merchant(name: "Spirit Airlines", category: .travel, keywords: ["spirit"]),
        Merchant(name: "Frontier Airlines", category: .travel, keywords: ["frontier"]),
        Merchant(name: "Hawaiian Airlines", category: .travel, keywords: ["hawaiian airlines"]),

        // Travel - Hotels
        Merchant(name: "Airbnb", category: .travel, keywords: ["airbnb"]),
        Merchant(name: "Marriott", category: .travel, keywords: ["marriott"]),
        Merchant(name: "Hilton", category: .travel, keywords: ["hilton"]),
        Merchant(name: "Hyatt", category: .travel, keywords: ["hyatt"]),
        Merchant(name: "IHG", category: .travel, keywords: ["ihg", "holiday inn"]),
        Merchant(name: "Best Western", category: .travel, keywords: ["best western"]),
        Merchant(name: "Wyndham", category: .travel, keywords: ["wyndham"]),
        Merchant(name: "VRBO", category: .travel, keywords: ["vrbo"]),
        Merchant(name: "Booking.com", category: .travel, keywords: ["booking.com", "booking"]),
        Merchant(name: "Expedia", category: .travel, keywords: ["expedia"]),
        Merchant(name: "Hotels.com", category: .travel, keywords: ["hotels.com"]),
        Merchant(name: "Priceline", category: .travel, keywords: ["priceline"]),
        Merchant(name: "Kayak", category: .travel, keywords: ["kayak"]),

        // Travel - Car Rental
        Merchant(name: "Enterprise", category: .travel, keywords: ["enterprise"]),
        Merchant(name: "Hertz", category: .travel, keywords: ["hertz"]),
        Merchant(name: "Avis", category: .travel, keywords: ["avis"]),
        Merchant(name: "Budget", category: .travel, keywords: ["budget"]),
        Merchant(name: "National", category: .travel, keywords: ["national car"]),
        Merchant(name: "Turo", category: .travel, keywords: ["turo"]),

        // Transit
        Merchant(name: "Uber", category: .transit, keywords: ["uber"]),
        Merchant(name: "Lyft", category: .transit, keywords: ["lyft"]),
        Merchant(name: "Metro", category: .transit, keywords: ["metro", "subway"]),
        Merchant(name: "BART", category: .transit, keywords: ["bart"]),
        Merchant(name: "MTA", category: .transit, keywords: ["mta"]),
        Merchant(name: "Amtrak", category: .transit, keywords: ["amtrak"]),
        Merchant(name: "Lime", category: .transit, keywords: ["lime scooter"]),
        Merchant(name: "Bird", category: .transit, keywords: ["bird scooter"]),

        // Drugstore
        Merchant(name: "CVS", category: .drugstore, keywords: ["cvs"]),
        Merchant(name: "Walgreens", category: .drugstore, keywords: ["walgreens"]),
        Merchant(name: "Rite Aid", category: .drugstore, keywords: ["rite aid"]),
        Merchant(name: "Duane Reade", category: .drugstore, keywords: ["duane reade"]),

        // Home Improvement
        Merchant(name: "Home Depot", category: .homeImprovement, keywords: ["home depot"]),
        Merchant(name: "Lowe's", category: .homeImprovement, keywords: ["lowes", "lowe's"]),
        Merchant(name: "Menards", category: .homeImprovement, keywords: ["menards"]),
        Merchant(name: "Ace Hardware", category: .homeImprovement, keywords: ["ace hardware"]),
        Merchant(name: "True Value", category: .homeImprovement, keywords: ["true value"]),

        // Entertainment
        Merchant(name: "AMC Theatres", category: .entertainment, keywords: ["amc"]),
        Merchant(name: "Regal Cinemas", category: .entertainment, keywords: ["regal"]),
        Merchant(name: "Cinemark", category: .entertainment, keywords: ["cinemark"]),
        Merchant(name: "Dave & Buster's", category: .entertainment, keywords: ["dave and busters", "dave & buster"]),
        Merchant(name: "Topgolf", category: .entertainment, keywords: ["topgolf"]),
        Merchant(name: "Six Flags", category: .entertainment, keywords: ["six flags"]),
        Merchant(name: "Universal Studios", category: .entertainment, keywords: ["universal studios"]),
        Merchant(name: "Disneyland", category: .entertainment, keywords: ["disneyland", "disney world"]),
        Merchant(name: "SeaWorld", category: .entertainment, keywords: ["seaworld"]),
        Merchant(name: "Ticketmaster", category: .entertainment, keywords: ["ticketmaster"]),
        Merchant(name: "StubHub", category: .entertainment, keywords: ["stubhub"]),
        Merchant(name: "Eventbrite", category: .entertainment, keywords: ["eventbrite"]),

        // PayPal
        Merchant(name: "PayPal", category: .paypal, keywords: ["paypal"]),
        Merchant(name: "Venmo", category: .paypal, keywords: ["venmo"]),

        // Utilities
        Merchant(name: "AT&T", category: .utilities, keywords: ["at&t", "att"]),
        Merchant(name: "Verizon", category: .utilities, keywords: ["verizon"]),
        Merchant(name: "T-Mobile", category: .utilities, keywords: ["t-mobile", "tmobile"]),
        Merchant(name: "Comcast", category: .utilities, keywords: ["comcast", "xfinity"]),
        Merchant(name: "Spectrum", category: .utilities, keywords: ["spectrum"]),
        Merchant(name: "Cox", category: .utilities, keywords: ["cox"]),

        // Fitness
        Merchant(name: "Planet Fitness", category: .other, keywords: ["planet fitness"]),
        Merchant(name: "LA Fitness", category: .other, keywords: ["la fitness"]),
        Merchant(name: "Equinox", category: .other, keywords: ["equinox"]),
        Merchant(name: "24 Hour Fitness", category: .other, keywords: ["24 hour fitness"]),
        Merchant(name: "Orangetheory", category: .other, keywords: ["orangetheory"]),
        Merchant(name: "CrossFit", category: .other, keywords: ["crossfit"]),
        Merchant(name: "Peloton", category: .other, keywords: ["peloton"]),

        // Pet Stores
        Merchant(name: "PetSmart", category: .other, keywords: ["petsmart"]),
        Merchant(name: "Petco", category: .other, keywords: ["petco"]),
        Merchant(name: "Chewy", category: .onlineShopping, keywords: ["chewy"]),

        // Coffee Shops
        Merchant(name: "Dutch Bros", category: .dining, keywords: ["dutch bros"]),
        Merchant(name: "Peet's Coffee", category: .dining, keywords: ["peets", "peet's"]),
        Merchant(name: "Philz Coffee", category: .dining, keywords: ["philz"]),
        Merchant(name: "Blue Bottle", category: .dining, keywords: ["blue bottle"]),
        Merchant(name: "Tim Hortons", category: .dining, keywords: ["tim hortons"]),

        // Fast Casual
        Merchant(name: "Raising Cane's", category: .dining, keywords: ["raising canes", "canes"]),
        Merchant(name: "Culver's", category: .dining, keywords: ["culvers", "culver's"]),
        Merchant(name: "Noodles & Company", category: .dining, keywords: ["noodles & company", "noodles and company"]),
        Merchant(name: "Qdoba", category: .dining, keywords: ["qdoba"]),
        Merchant(name: "Jersey Mike's", category: .dining, keywords: ["jersey mikes", "jersey mike's"]),
        Merchant(name: "Firehouse Subs", category: .dining, keywords: ["firehouse subs"]),
        Merchant(name: "Jimmy John's", category: .dining, keywords: ["jimmy johns", "jimmy john's"]),
        Merchant(name: "Potbelly", category: .dining, keywords: ["potbelly"]),
        Merchant(name: "Blaze Pizza", category: .dining, keywords: ["blaze pizza"]),
        Merchant(name: "MOD Pizza", category: .dining, keywords: ["mod pizza"]),
        Merchant(name: "Cava", category: .dining, keywords: ["cava"]),
        Merchant(name: "Sweetgreen", category: .dining, keywords: ["sweetgreen"]),
        Merchant(name: "Chopt", category: .dining, keywords: ["chopt"]),

        // Department & Retail Stores
        Merchant(name: "Kohl's", category: .other, keywords: ["kohls", "kohl's"]),
        Merchant(name: "JCPenney", category: .other, keywords: ["jcpenney", "jc penney"]),
        Merchant(name: "Dillard's", category: .other, keywords: ["dillards", "dillard's"]),
        Merchant(name: "Belk", category: .other, keywords: ["belk"]),
        Merchant(name: "Ross", category: .other, keywords: ["ross"]),
        Merchant(name: "TJ Maxx", category: .other, keywords: ["tj maxx", "tjmaxx"]),
        Merchant(name: "Marshalls", category: .other, keywords: ["marshalls"]),
        Merchant(name: "HomeGoods", category: .other, keywords: ["homegoods", "home goods"]),
        Merchant(name: "Burlington", category: .other, keywords: ["burlington"]),

        // Clothing & Fashion
        Merchant(name: "Old Navy", category: .other, keywords: ["old navy"]),
        Merchant(name: "Gap", category: .other, keywords: ["gap"]),
        Merchant(name: "Banana Republic", category: .other, keywords: ["banana republic"]),
        Merchant(name: "H&M", category: .other, keywords: ["h&m", "hm"]),
        Merchant(name: "Zara", category: .other, keywords: ["zara"]),
        Merchant(name: "Uniqlo", category: .other, keywords: ["uniqlo"]),
        Merchant(name: "Forever 21", category: .other, keywords: ["forever 21"]),
        Merchant(name: "Express", category: .other, keywords: ["express"]),
        Merchant(name: "Abercrombie", category: .other, keywords: ["abercrombie"]),
        Merchant(name: "American Eagle", category: .other, keywords: ["american eagle", "aerie"]),
        Merchant(name: "Lululemon", category: .other, keywords: ["lululemon"]),
        Merchant(name: "Athleta", category: .other, keywords: ["athleta"]),
        Merchant(name: "REI", category: .other, keywords: ["rei"]),
        Merchant(name: "Dick's Sporting Goods", category: .other, keywords: ["dicks", "dick's sporting"]),

        // Discount Stores
        Merchant(name: "Dollar Tree", category: .other, keywords: ["dollar tree"]),
        Merchant(name: "Dollar General", category: .other, keywords: ["dollar general"]),
        Merchant(name: "Five Below", category: .other, keywords: ["five below"]),
        Merchant(name: "Big Lots", category: .other, keywords: ["big lots"]),

        // Office Supplies
        Merchant(name: "Staples", category: .other, keywords: ["staples"]),
        Merchant(name: "Office Depot", category: .other, keywords: ["office depot", "officemax"]),

        // Beauty & Personal Care
        Merchant(name: "Ulta", category: .other, keywords: ["ulta"]),
        Merchant(name: "Sephora", category: .other, keywords: ["sephora"]),
        Merchant(name: "Bath & Body Works", category: .other, keywords: ["bath & body works", "bath and body"]),
        Merchant(name: "Sally Beauty", category: .other, keywords: ["sally beauty"]),

        // Bookstores
        Merchant(name: "Barnes & Noble", category: .other, keywords: ["barnes & noble", "barnes and noble"]),
        Merchant(name: "Books-A-Million", category: .other, keywords: ["books a million"]),

        // Electronics
        Merchant(name: "Micro Center", category: .other, keywords: ["micro center"]),
        Merchant(name: "B&H Photo", category: .other, keywords: ["b&h", "b&h photo"]),
        Merchant(name: "GameStop", category: .other, keywords: ["gamestop"]),

        // More Grocery Stores
        Merchant(name: "WinCo", category: .grocery, keywords: ["winco"]),
        Merchant(name: "Ralph's", category: .grocery, keywords: ["ralphs", "ralph's"]),
        Merchant(name: "Hy-Vee", category: .grocery, keywords: ["hy-vee", "hyvee"]),
        Merchant(name: "ShopRite", category: .grocery, keywords: ["shoprite"]),
        Merchant(name: "Jewel-Osco", category: .grocery, keywords: ["jewel-osco", "jewel osco"]),
        Merchant(name: "Fry's Food", category: .grocery, keywords: ["frys", "fry's food"]),
        Merchant(name: "Fred Meyer", category: .grocery, keywords: ["fred meyer"]),
        Merchant(name: "Schnucks", category: .grocery, keywords: ["schnucks"]),
        Merchant(name: "Lucky Supermarkets", category: .grocery, keywords: ["lucky"]),

        // Furniture & Home
        Merchant(name: "IKEA", category: .other, keywords: ["ikea"]),
        Merchant(name: "Bed Bath & Beyond", category: .other, keywords: ["bed bath"]),
        Merchant(name: "Crate & Barrel", category: .other, keywords: ["crate & barrel", "crate and barrel"]),
        Merchant(name: "Williams-Sonoma", category: .other, keywords: ["williams-sonoma", "williams sonoma"]),
        Merchant(name: "Pottery Barn", category: .other, keywords: ["pottery barn"]),
        Merchant(name: "West Elm", category: .other, keywords: ["west elm"]),
        Merchant(name: "At Home", category: .other, keywords: ["at home"]),
        Merchant(name: "World Market", category: .other, keywords: ["world market"]),

        // Auto
        Merchant(name: "AutoZone", category: .other, keywords: ["autozone"]),
        Merchant(name: "O'Reilly Auto", category: .other, keywords: ["oreilly", "o'reilly auto"]),
        Merchant(name: "Advance Auto Parts", category: .other, keywords: ["advance auto"]),
        Merchant(name: "NAPA", category: .other, keywords: ["napa"]),
        Merchant(name: "Jiffy Lube", category: .other, keywords: ["jiffy lube"]),
        Merchant(name: "Valvoline", category: .other, keywords: ["valvoline"]),

        // Warehouse Clubs (already have Costco, Sam's, BJ's)

        // Specialty Food
        Merchant(name: "The Fresh Market", category: .grocery, keywords: ["fresh market"]),
        Merchant(name: "Natural Grocers", category: .grocery, keywords: ["natural grocers"]),
        Merchant(name: "Earth Fare", category: .grocery, keywords: ["earth fare"]),
    ]

    static func findMerchant(query: String) -> Merchant? {
        let lowercased = query.lowercased()

        // Exact match first
        if let exact = merchants.first(where: { $0.name.lowercased() == lowercased }) {
            return exact
        }

        // Keyword match
        for merchant in merchants where merchant.keywords != nil {
            for keyword in merchant.keywords! where lowercased.contains(keyword) {
                return merchant
            }
        }

        // Partial name match
        if let partial = merchants.first(where: { $0.name.lowercased().contains(lowercased) || lowercased.contains($0.name.lowercased()) }) {
            return partial
        }

        return nil
    }

    static func suggestCategory(for query: String) -> SpendingCategory? {
        findMerchant(query: query)?.category
    }

    // Get matching merchants for autocomplete
    static func searchMerchants(query: String) -> [Merchant] {
        guard !query.isEmpty else { return [] }
        let lowercased = query.lowercased()

        return merchants.filter { merchant in
            // Match name
            if merchant.name.lowercased().contains(lowercased) {
                return true
            }
            // Match keywords
            if let keywords = merchant.keywords {
                for keyword in keywords {
                    if keyword.contains(lowercased) || lowercased.contains(keyword) {
                        return true
                    }
                }
            }
            return false
        }
    }
}
