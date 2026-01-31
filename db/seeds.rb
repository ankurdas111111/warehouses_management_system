## Seeds: realistic India dataset (warehouses + SKUs + stock)
#
# Goals:
# - Provide a lot of realistic data to explore the UI and APIs.
# - Stay idempotent (safe to run multiple times).
# - Use only cities present in IndianCities::CITIES so distance-based allocation works.
# - Do NOT create users/admin accounts (per request).
#
# Controls:
# - SEED_SCALE=1 (default) => ~18 warehouses, ~55 SKUs
# - SEED_SCALE=2           => more warehouses/SKUs
#
# NOTE: SKU prices are stored in integer INR minor units (paise) in `price_cents`.

SEED_SCALE = [ ENV.fetch("SEED_SCALE", "1").to_i, 1 ].max
RNG = Random.new(2026) # deterministic, stable across runs

def slug_code(s)
  s.to_s.strip.upcase.gsub(/[^A-Z0-9]+/, "_").gsub(/^_+|_+$/, "")
end

def inr_to_paise(inr)
  (inr.to_f * 100).round
end

warehouse_templates = [
  "Astra Fulfillment Center",
  "Kaveri Logistics Hub",
  "Saffron Supply Depot",
  "Monsoon Distribution Center",
  "Shakti Warehouse",
  "Narmada Fulfillment",
  "Deccan Storage Park",
  "Coastal Dispatch Hub"
].freeze

sku_catalog = [
  { code: "ATTA_WHEAT_10KG", name: "Whole Wheat Atta 10 kg", price_inr: 449 },
  { code: "RICE_BASMATI_5KG", name: "Basmati Rice 5 kg", price_inr: 699 },
  { code: "DAL_TUR_1KG", name: "Toor Dal 1 kg", price_inr: 189 },
  { code: "DAL_MOONG_1KG", name: "Moong Dal 1 kg", price_inr: 169 },
  { code: "OIL_GROUNDNUT_1L", name: "Groundnut Oil 1 L", price_inr: 249 },
  { code: "OIL_SUNFLOWER_1L", name: "Sunflower Oil 1 L", price_inr: 199 },
  { code: "GHEE_1L", name: "Cow Ghee 1 L", price_inr: 649 },
  { code: "TEA_ASSAM_500G", name: "Assam Tea 500 g", price_inr: 299 },
  { code: "COFFEE_FILTER_500G", name: "Filter Coffee 500 g", price_inr: 399 },
  { code: "SUGAR_5KG", name: "Sugar 5 kg", price_inr: 239 },
  { code: "SALT_ROCK_1KG", name: "Rock Salt 1 kg", price_inr: 49 },
  { code: "SPICE_TURMERIC_200G", name: "Turmeric Powder 200 g", price_inr: 59 },
  { code: "SPICE_CHILLI_200G", name: "Red Chilli Powder 200 g", price_inr: 69 },
  { code: "SPICE_GARAM_MASALA_100G", name: "Garam Masala 100 g", price_inr: 89 },
  { code: "BISCUITS_DIGESTIVE_1KG", name: "Digestive Biscuits 1 kg", price_inr: 299 },
  { code: "NOODLES_INSTANT_12PK", name: "Instant Noodles (12 pack)", price_inr: 199 },
  { code: "MILK_POWDER_1KG", name: "Milk Powder 1 kg", price_inr: 459 },
  { code: "CEREAL_OATS_1KG", name: "Oats 1 kg", price_inr: 219 },
  { code: "HONEY_500G", name: "Wildflower Honey 500 g", price_inr: 299 },
  { code: "PEANUT_BUTTER_1KG", name: "Peanut Butter 1 kg", price_inr: 399 },

  { code: "SHAMPOO_HERBAL_650ML", name: "Herbal Shampoo 650 ml", price_inr: 349 },
  { code: "SOAP_SANDAL_6PK", name: "Sandal Soap (6 pack)", price_inr: 179 },
  { code: "TOOTHPASTE_MINT_200G", name: "Mint Toothpaste 200 g", price_inr: 129 },
  { code: "DETERGENT_5KG", name: "Laundry Detergent 5 kg", price_inr: 479 },
  { code: "DISHWASH_GEL_500ML", name: "Dishwash Gel 500 ml", price_inr: 99 },
  { code: "TISSUE_ROLL_12PK", name: "Tissue Rolls (12 pack)", price_inr: 399 },

  { code: "NOTEBOOK_A4_5PK", name: "A4 Notebooks (5 pack)", price_inr: 199 },
  { code: "PEN_GEL_10PK", name: "Gel Pens (10 pack)", price_inr: 149 },
  { code: "USB_C_CABLE_1M", name: "USB‑C Cable 1 m", price_inr: 199 },
  { code: "POWER_BANK_10000", name: "Power Bank 10,000 mAh", price_inr: 1099 },
  { code: "EARPHONES_WIRED", name: "Wired Earphones", price_inr: 399 },

  { code: "T_SHIRT_COTTON_M", name: "Cotton T‑Shirt (M)", price_inr: 499 },
  { code: "T_SHIRT_COTTON_L", name: "Cotton T‑Shirt (L)", price_inr: 499 },
  { code: "JEANS_DENIM_32", name: "Denim Jeans (32)", price_inr: 1499 },
  { code: "SHOES_RUNNING_9", name: "Running Shoes (UK 9)", price_inr: 1999 },

  { code: "MUG_STEEL_350ML", name: "Steel Mug 350 ml", price_inr: 249 },
  { code: "BOTTLE_INSULATED_1L", name: "Insulated Bottle 1 L", price_inr: 799 },
  { code: "COOKWARE_NONSTICK", name: "Non‑stick Cookware Set", price_inr: 1799 },

  { code: "PHONE_CASE_SILICONE", name: "Silicone Phone Case", price_inr: 249 },
  { code: "SCREEN_GUARD_2PK", name: "Screen Guard (2 pack)", price_inr: 199 },
  { code: "LAPTOP_SLEEVE_15", name: "Laptop Sleeve 15\"", price_inr: 699 },

  { code: "CRICKET_BAT_KASHMIR", name: "Cricket Bat (Kashmir Willow)", price_inr: 1299 },
  { code: "BADMINTON_RACKET", name: "Badminton Racket", price_inr: 899 },
  { code: "YOGA_MAT_6MM", name: "Yoga Mat 6 mm", price_inr: 599 },

  { code: "PLANT_POT_8IN", name: "Plant Pot 8 in", price_inr: 199 },
  { code: "WATERING_CAN_1_5L", name: "Watering Can 1.5 L", price_inr: 299 }
].freeze

base_cities = IndianCities::CITIES.dup
selected_cities = base_cities.sample([ 18 * SEED_SCALE, base_cities.size ].min, random: RNG)

puts "Seeding warehouses (#{selected_cities.size})..."
warehouses =
  selected_cities.each_with_index.map do |city, idx|
    canonical_city = IndianCities.canonical(city) || city
    code = format("WH-%<city>s-%<n>02d", city: slug_code(canonical_city)[0, 3], n: idx + 1)
    name = "#{warehouse_templates.sample(random: RNG)} — #{canonical_city}"

    Warehouse.find_or_create_by!(code: code) do |w|
      w.name = name
      w.location = canonical_city
    end.tap do |w|
      # keep seed reruns consistent if you change templates later
      w.update!(name: name, location: canonical_city) if w.name != name || w.location != canonical_city
    end
  end

extra_skus =
  (1..(15 * SEED_SCALE)).map do |i|
    {
      code: "SNACKS_MIX_#{format('%02d', i)}",
      name: [ "Namkeen Mix", "Chakli", "Murukku", "Khakhra", "Roasted Chana" ].sample(random: RNG) + " (#{format('%02d', i)})",
      price_inr: [ 79, 99, 129, 149, 179 ].sample(random: RNG)
    }
  end

all_skus = (sku_catalog + extra_skus).uniq { |x| x[:code] }

puts "Seeding SKUs (#{all_skus.size})..."
skus =
  all_skus.map do |h|
    price_paise = inr_to_paise(h.fetch(:price_inr))
    Sku.find_or_create_by!(code: h.fetch(:code)) do |s|
      s.name = h.fetch(:name)
      s.price_cents = price_paise
    end.tap do |s|
      # keep seed reruns consistent
      if s.name != h[:name] || s.price_cents.to_i != price_paise
        s.update!(name: h[:name], price_cents: price_paise)
      end
    end
  end

puts "Seeding stock items..."
warehouses_by_city = warehouses.group_by(&:location)

skus.each do |sku|
  # Stock each SKU in 6–10 warehouses so orders can split across locations.
  wh_count = [ [ 6 + RNG.rand(5), warehouses.size ].min, 1 ].max
  chosen_whs = warehouses.sample(wh_count, random: RNG)

  chosen_whs.each do |wh|
    # Bias slightly: more stock in the warehouse's own city "category"
    base = 10 + RNG.rand(220)
    city_bonus = warehouses_by_city[wh.location].to_a.size > 1 ? RNG.rand(40) : 0
    on_hand = base + city_bonus

    StockItem.find_or_create_by!(sku: sku, warehouse: wh) do |si|
      si.on_hand = on_hand
  si.reserved = 0
    end.tap do |si|
      # Do not clobber reserved in case you're actively testing flows.
      si.update!(on_hand: on_hand) if si.on_hand.to_i != on_hand
    end
  end
end

puts "Seed complete: #{Warehouse.count} warehouses, #{Sku.count} SKUs, #{StockItem.count} stock items."
