/// A major seaport — backs the From/To autocomplete on the Voyage Details
/// form. Deliberately a bundled static list (no geocoding API, no new
/// dependency, no network call) — matches this app's minimal-dependency
/// style and needs nothing beyond what's already in the app bundle.
class Port {
  const Port({required this.name, required this.city, required this.country});

  /// The port's formal name (e.g. "Port of Yokohama").
  final String name;
  final String city;
  final String country;

  /// What gets written into the From/To field once picked.
  String get displayLabel => '$city, $country';

  /// Whether [query] (already lowercased) appears in the port name, city, or
  /// country — a sailor can search by any of the three.
  bool matches(String query) =>
      name.toLowerCase().contains(query) ||
      city.toLowerCase().contains(query) ||
      country.toLowerCase().contains(query);
}

/// ~180 major world seaports spanning every populated continent, enough for
/// an autocomplete to feel genuinely useful without bundling a full global
/// gazetteer.
const List<Port> kWorldPorts = [
  // East Asia
  Port(name: 'Port of Shanghai', city: 'Shanghai', country: 'China'),
  Port(name: 'Port of Ningbo-Zhoushan', city: 'Ningbo', country: 'China'),
  Port(name: 'Port of Shenzhen', city: 'Shenzhen', country: 'China'),
  Port(name: 'Port of Guangzhou', city: 'Guangzhou', country: 'China'),
  Port(name: 'Port of Qingdao', city: 'Qingdao', country: 'China'),
  Port(name: 'Port of Tianjin', city: 'Tianjin', country: 'China'),
  Port(name: 'Port of Dalian', city: 'Dalian', country: 'China'),
  Port(name: 'Port of Xiamen', city: 'Xiamen', country: 'China'),
  Port(name: 'Port of Hong Kong', city: 'Hong Kong', country: 'Hong Kong'),
  Port(name: 'Port of Kaohsiung', city: 'Kaohsiung', country: 'Taiwan'),
  Port(name: 'Port of Keelung', city: 'Keelung', country: 'Taiwan'),
  Port(name: 'Port of Yokohama', city: 'Yokohama', country: 'Japan'),
  Port(name: 'Port of Tokyo', city: 'Tokyo', country: 'Japan'),
  Port(name: 'Port of Kobe', city: 'Kobe', country: 'Japan'),
  Port(name: 'Port of Osaka', city: 'Osaka', country: 'Japan'),
  Port(name: 'Port of Nagoya', city: 'Nagoya', country: 'Japan'),
  Port(name: 'Port of Busan', city: 'Busan', country: 'South Korea'),
  Port(name: 'Port of Incheon', city: 'Incheon', country: 'South Korea'),
  Port(name: 'Port of Vladivostok', city: 'Vladivostok', country: 'Russia'),

  // Southeast & South Asia
  Port(name: 'Port of Singapore', city: 'Singapore', country: 'Singapore'),
  Port(name: 'Port Klang', city: 'Port Klang', country: 'Malaysia'),
  Port(name: 'Port of Tanjung Pelepas', city: 'Johor', country: 'Malaysia'),
  Port(
    name: 'Tanjung Priok Port',
    city: 'Jakarta',
    country: 'Indonesia',
  ),
  Port(name: 'Port of Surabaya', city: 'Surabaya', country: 'Indonesia'),
  Port(name: 'Port of Manila', city: 'Manila', country: 'Philippines'),
  Port(name: 'Port of Cebu', city: 'Cebu', country: 'Philippines'),
  Port(
    name: 'Laem Chabang Port',
    city: 'Laem Chabang',
    country: 'Thailand',
  ),
  Port(name: 'Port of Bangkok', city: 'Bangkok', country: 'Thailand'),
  Port(name: 'Port of Ho Chi Minh City', city: 'Ho Chi Minh City', country: 'Vietnam'),
  Port(name: 'Port of Haiphong', city: 'Haiphong', country: 'Vietnam'),
  Port(name: 'Port of Yangon', city: 'Yangon', country: 'Myanmar'),
  Port(name: 'Port of Colombo', city: 'Colombo', country: 'Sri Lanka'),
  Port(
    name: 'Jawaharlal Nehru Port',
    city: 'Mumbai',
    country: 'India',
  ),
  Port(name: 'Port of Chennai', city: 'Chennai', country: 'India'),
  Port(name: 'Port of Kolkata', city: 'Kolkata', country: 'India'),
  Port(name: 'Port of Kochi', city: 'Kochi', country: 'India'),
  Port(name: 'Port of Karachi', city: 'Karachi', country: 'Pakistan'),
  Port(name: 'Port of Chittagong', city: 'Chittagong', country: 'Bangladesh'),

  // Middle East
  Port(name: 'Jebel Ali Port', city: 'Dubai', country: 'United Arab Emirates'),
  Port(name: 'Port of Abu Dhabi', city: 'Abu Dhabi', country: 'United Arab Emirates'),
  Port(name: 'Port of Jeddah', city: 'Jeddah', country: 'Saudi Arabia'),
  Port(name: 'Port of Dammam', city: 'Dammam', country: 'Saudi Arabia'),
  Port(name: 'Port of Doha', city: 'Doha', country: 'Qatar'),
  Port(name: 'Port of Salalah', city: 'Salalah', country: 'Oman'),
  Port(name: 'Port of Muscat', city: 'Muscat', country: 'Oman'),
  Port(name: 'Port of Haifa', city: 'Haifa', country: 'Israel'),
  Port(name: 'Port of Beirut', city: 'Beirut', country: 'Lebanon'),
  Port(name: 'Port of Bandar Abbas', city: 'Bandar Abbas', country: 'Iran'),
  Port(name: 'Port of Istanbul', city: 'Istanbul', country: 'Turkey'),
  Port(name: 'Port of Izmir', city: 'Izmir', country: 'Turkey'),

  // Europe
  Port(name: 'Port of Rotterdam', city: 'Rotterdam', country: 'Netherlands'),
  Port(name: 'Port of Antwerp', city: 'Antwerp', country: 'Belgium'),
  Port(name: 'Port of Hamburg', city: 'Hamburg', country: 'Germany'),
  Port(name: 'Port of Bremerhaven', city: 'Bremerhaven', country: 'Germany'),
  Port(name: 'Port of Le Havre', city: 'Le Havre', country: 'France'),
  Port(name: 'Port of Marseille', city: 'Marseille', country: 'France'),
  Port(name: 'Port of Valencia', city: 'Valencia', country: 'Spain'),
  Port(name: 'Port of Barcelona', city: 'Barcelona', country: 'Spain'),
  Port(name: 'Port of Algeciras', city: 'Algeciras', country: 'Spain'),
  Port(name: 'Port of Bilbao', city: 'Bilbao', country: 'Spain'),
  Port(name: 'Port of Lisbon', city: 'Lisbon', country: 'Portugal'),
  Port(name: 'Port of Genoa', city: 'Genoa', country: 'Italy'),
  Port(name: 'Port of Naples', city: 'Naples', country: 'Italy'),
  Port(name: 'Port of Venice', city: 'Venice', country: 'Italy'),
  Port(name: 'Port of Trieste', city: 'Trieste', country: 'Italy'),
  Port(name: 'Piraeus Port', city: 'Piraeus', country: 'Greece'),
  Port(name: 'Port of Thessaloniki', city: 'Thessaloniki', country: 'Greece'),
  Port(name: 'Port of Gdansk', city: 'Gdansk', country: 'Poland'),
  Port(name: 'Port of Gdynia', city: 'Gdynia', country: 'Poland'),
  Port(name: 'Port of Felixstowe', city: 'Felixstowe', country: 'United Kingdom'),
  Port(name: 'Port of Southampton', city: 'Southampton', country: 'United Kingdom'),
  Port(name: 'Port of London', city: 'London', country: 'United Kingdom'),
  Port(name: 'Port of Liverpool', city: 'Liverpool', country: 'United Kingdom'),
  Port(name: 'Port of Dublin', city: 'Dublin', country: 'Ireland'),
  Port(name: 'Port of Gothenburg', city: 'Gothenburg', country: 'Sweden'),
  Port(name: 'Port of Stockholm', city: 'Stockholm', country: 'Sweden'),
  Port(name: 'Port of Copenhagen', city: 'Copenhagen', country: 'Denmark'),
  Port(name: 'Port of Oslo', city: 'Oslo', country: 'Norway'),
  Port(name: 'Port of Bergen', city: 'Bergen', country: 'Norway'),
  Port(name: 'Port of Helsinki', city: 'Helsinki', country: 'Finland'),
  Port(name: 'Port of Tallinn', city: 'Tallinn', country: 'Estonia'),
  Port(name: 'Port of Riga', city: 'Riga', country: 'Latvia'),
  Port(name: 'Port of Klaipeda', city: 'Klaipeda', country: 'Lithuania'),
  Port(name: 'Port of Constanta', city: 'Constanta', country: 'Romania'),
  Port(name: 'Port of Odesa', city: 'Odesa', country: 'Ukraine'),
  Port(name: 'Port of St. Petersburg', city: 'St. Petersburg', country: 'Russia'),
  Port(name: 'Port of Reykjavik', city: 'Reykjavik', country: 'Iceland'),

  // Africa
  Port(name: 'Port of Durban', city: 'Durban', country: 'South Africa'),
  Port(name: 'Port of Cape Town', city: 'Cape Town', country: 'South Africa'),
  Port(name: 'Port Elizabeth', city: 'Gqeberha', country: 'South Africa'),
  Port(name: 'Port of Lagos', city: 'Lagos', country: 'Nigeria'),
  Port(name: 'Port of Mombasa', city: 'Mombasa', country: 'Kenya'),
  Port(name: 'Port of Dar es Salaam', city: 'Dar es Salaam', country: 'Tanzania'),
  Port(name: 'Port of Alexandria', city: 'Alexandria', country: 'Egypt'),
  Port(name: 'Port Said', city: 'Port Said', country: 'Egypt'),
  Port(name: 'Port of Casablanca', city: 'Casablanca', country: 'Morocco'),
  Port(name: 'Tanger Med Port', city: 'Tangier', country: 'Morocco'),
  Port(name: 'Port of Tunis', city: 'Tunis', country: 'Tunisia'),
  Port(name: 'Port of Algiers', city: 'Algiers', country: 'Algeria'),
  Port(name: 'Port of Abidjan', city: 'Abidjan', country: "Ivory Coast"),
  Port(name: 'Port of Accra', city: 'Accra', country: 'Ghana'),
  Port(name: 'Port of Luanda', city: 'Luanda', country: 'Angola'),
  Port(name: 'Port of Djibouti', city: 'Djibouti', country: 'Djibouti'),

  // North America
  Port(name: 'Port of Los Angeles', city: 'Los Angeles', country: 'United States'),
  Port(name: 'Port of Long Beach', city: 'Long Beach', country: 'United States'),
  Port(name: 'Port of New York and New Jersey', city: 'New York', country: 'United States'),
  Port(name: 'Port of Savannah', city: 'Savannah', country: 'United States'),
  Port(name: 'Port of Seattle', city: 'Seattle', country: 'United States'),
  Port(name: 'Port of Tacoma', city: 'Tacoma', country: 'United States'),
  Port(name: 'Port of Oakland', city: 'Oakland', country: 'United States'),
  Port(name: 'Port of Houston', city: 'Houston', country: 'United States'),
  Port(name: 'Port of Miami', city: 'Miami', country: 'United States'),
  Port(name: 'Port Everglades', city: 'Fort Lauderdale', country: 'United States'),
  Port(name: 'Port of Charleston', city: 'Charleston', country: 'United States'),
  Port(name: 'Port of Boston', city: 'Boston', country: 'United States'),
  Port(name: 'Port of Baltimore', city: 'Baltimore', country: 'United States'),
  Port(name: 'Port of Honolulu', city: 'Honolulu', country: 'United States'),
  Port(name: 'Port of Anchorage', city: 'Anchorage', country: 'United States'),
  Port(name: 'Port of San Francisco', city: 'San Francisco', country: 'United States'),
  Port(name: 'Port of San Diego', city: 'San Diego', country: 'United States'),
  Port(name: 'Port of New Orleans', city: 'New Orleans', country: 'United States'),
  Port(name: 'Port Metro Vancouver', city: 'Vancouver', country: 'Canada'),
  Port(name: 'Port of Montreal', city: 'Montreal', country: 'Canada'),
  Port(name: 'Port of Halifax', city: 'Halifax', country: 'Canada'),
  Port(name: 'Port of Prince Rupert', city: 'Prince Rupert', country: 'Canada'),
  Port(name: 'Port of Manzanillo', city: 'Manzanillo', country: 'Mexico'),
  Port(name: 'Port of Veracruz', city: 'Veracruz', country: 'Mexico'),
  Port(name: 'Port of Ensenada', city: 'Ensenada', country: 'Mexico'),
  Port(name: 'Port of Kingston', city: 'Kingston', country: 'Jamaica'),
  Port(name: 'Port of Havana', city: 'Havana', country: 'Cuba'),
  Port(name: 'Port of Nassau', city: 'Nassau', country: 'Bahamas'),
  Port(name: 'Colón Container Terminal', city: 'Colón', country: 'Panama'),
  Port(name: 'Port of Balboa', city: 'Panama City', country: 'Panama'),

  // South America
  Port(name: 'Port of Santos', city: 'Santos', country: 'Brazil'),
  Port(name: 'Port of Rio de Janeiro', city: 'Rio de Janeiro', country: 'Brazil'),
  Port(name: 'Port of Itajai', city: 'Itajai', country: 'Brazil'),
  Port(name: 'Port of Buenos Aires', city: 'Buenos Aires', country: 'Argentina'),
  Port(name: 'Port of Valparaiso', city: 'Valparaiso', country: 'Chile'),
  Port(name: 'Port of San Antonio', city: 'San Antonio', country: 'Chile'),
  Port(name: 'Port of Callao', city: 'Lima', country: 'Peru'),
  Port(name: 'Port of Guayaquil', city: 'Guayaquil', country: 'Ecuador'),
  Port(name: 'Port of Cartagena', city: 'Cartagena', country: 'Colombia'),
  Port(name: 'Port of Montevideo', city: 'Montevideo', country: 'Uruguay'),
  Port(name: 'Port of Georgetown', city: 'Georgetown', country: 'Guyana'),

  // Oceania
  Port(name: 'Port Botany', city: 'Sydney', country: 'Australia'),
  Port(name: 'Port of Melbourne', city: 'Melbourne', country: 'Australia'),
  Port(name: 'Port of Brisbane', city: 'Brisbane', country: 'Australia'),
  Port(name: 'Fremantle Port', city: 'Perth', country: 'Australia'),
  Port(name: 'Port Adelaide', city: 'Adelaide', country: 'Australia'),
  Port(name: 'Port of Auckland', city: 'Auckland', country: 'New Zealand'),
  Port(name: 'Port of Wellington', city: 'Wellington', country: 'New Zealand'),
  Port(name: 'Port of Suva', city: 'Suva', country: 'Fiji'),
  Port(name: 'Port of Papeete', city: 'Papeete', country: 'French Polynesia'),
  Port(name: 'Port of Noumea', city: 'Noumea', country: 'New Caledonia'),
  Port(name: 'Port of Apia', city: 'Apia', country: 'Samoa'),

  // Island & remote waypoints (nod to the app's sailing theme)
  Port(name: 'Port of Funchal', city: 'Funchal', country: 'Portugal'),
  Port(name: 'Port of Las Palmas', city: 'Las Palmas', country: 'Spain'),
  Port(name: 'Port of Bermuda', city: 'Hamilton', country: 'Bermuda'),
  Port(name: 'Port of Male', city: 'Male', country: 'Maldives'),
  Port(name: 'Port of Port Louis', city: 'Port Louis', country: 'Mauritius'),
  Port(name: 'Port of Victoria', city: 'Victoria', country: 'Seychelles'),
  Port(name: 'Cape Horn Anchorage', city: 'Puerto Williams', country: 'Chile'),
];
