module IndianCities
  # Curated list of large and commonly used Indian cities for consistent location tagging.
  # Used as suggestions (not a strict enum) so the system can evolve without migrations.
  CITIES = [
    "Ahmedabad",
    "Bengaluru",
    "Bhopal",
    "Bhubaneswar",
    "Chandigarh",
    "Chennai",
    "Coimbatore",
    "Dehradun",
    "Delhi",
    "Faridabad",
    "Ghaziabad",
    "Gurugram",
    "Guwahati",
    "Hyderabad",
    "Indore",
    "Jaipur",
    "Jodhpur",
    "Kanpur",
    "Kochi",
    "Kolkata",
    "Lucknow",
    "Ludhiana",
    "Mangaluru",
    "Mumbai",
    "Nagpur",
    "Nashik",
    "Noida",
    "Patna",
    "Pune",
    "Raipur",
    "Ranchi",
    "Surat",
    "Thane",
    "Thiruvananthapuram",
    "Vadodara",
    "Varanasi",
    "Visakhapatnam"
  ].freeze

  # Approximate city coordinates (latitude/longitude). Used to choose the nearest
  # warehouse location when delivery_city does not have stock.
  #
  # Source: public city centroids (approx). Precision is sufficient for ranking.
  COORDS = {
    "Ahmedabad" => [23.0225, 72.5714],
    "Bengaluru" => [12.9716, 77.5946],
    "Bhopal" => [23.2599, 77.4126],
    "Bhubaneswar" => [20.2961, 85.8245],
    "Chandigarh" => [30.7333, 76.7794],
    "Chennai" => [13.0827, 80.2707],
    "Coimbatore" => [11.0168, 76.9558],
    "Dehradun" => [30.3165, 78.0322],
    "Delhi" => [28.6139, 77.2090],
    "Faridabad" => [28.4089, 77.3178],
    "Ghaziabad" => [28.6692, 77.4538],
    "Gurugram" => [28.4595, 77.0266],
    "Guwahati" => [26.1445, 91.7362],
    "Hyderabad" => [17.3850, 78.4867],
    "Indore" => [22.7196, 75.8577],
    "Jaipur" => [26.9124, 75.7873],
    "Jodhpur" => [26.2389, 73.0243],
    "Kanpur" => [26.4499, 80.3319],
    "Kochi" => [9.9312, 76.2673],
    "Kolkata" => [22.5726, 88.3639],
    "Lucknow" => [26.8467, 80.9462],
    "Ludhiana" => [30.9010, 75.8573],
    "Mangaluru" => [12.9141, 74.8560],
    "Mumbai" => [19.0760, 72.8777],
    "Nagpur" => [21.1458, 79.0882],
    "Nashik" => [19.9975, 73.7898],
    "Noida" => [28.5355, 77.3910],
    "Patna" => [25.5941, 85.1376],
    "Pune" => [18.5204, 73.8567],
    "Raipur" => [21.2514, 81.6296],
    "Ranchi" => [23.3441, 85.3096],
    "Surat" => [21.1702, 72.8311],
    "Thane" => [19.2183, 72.9781],
    "Thiruvananthapuram" => [8.5241, 76.9366],
    "Vadodara" => [22.3072, 73.1812],
    "Varanasi" => [25.3176, 82.9739],
    "Visakhapatnam" => [17.6868, 83.2185]
  }.freeze

  def self.normalize(name)
    name.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  NORMALIZED_TO_CANONICAL =
    CITIES.to_h { |c| [normalize(c), c] }.freeze

  def self.canonical(name)
    NORMALIZED_TO_CANONICAL[normalize(name)]
  end

  def self.coords(name)
    COORDS[canonical(name) || name.to_s.strip]
  end

  def self.distance_km(from_city, to_city)
    from = coords(from_city)
    to = coords(to_city)
    return nil unless from && to

    haversine_km(from[0], from[1], to[0], to[1])
  end

  def self.haversine_km(lat1, lon1, lat2, lon2)
    rad_per_deg = Math::PI / 180.0
    r_km = 6371.0

    dlat = (lat2 - lat1) * rad_per_deg
    dlon = (lon2 - lon1) * rad_per_deg

    a =
      Math.sin(dlat / 2)**2 +
        Math.cos(lat1 * rad_per_deg) * Math.cos(lat2 * rad_per_deg) * Math.sin(dlon / 2)**2

    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    r_km * c
  end
end


