import 'package:cloud_firestore/cloud_firestore.dart';

final Map<String, Map<String, String>> venueData = {
  "Burlingame Aquatic Center": {
    "address": "1 Mangini Way, Burlingame, CA 94010",
    "zone": "1N"
  },
  "Palo Alto Rinconada Pool": {
    "address": "777 Embarcadero Rd, Palo Alto, CA 94303",
    "zone": "1N"
  },
  "Jean E. Brink Pool (Oceana)": {
    "address": "401 Paloma Ave, Pacifica, CA 94044",
    "zone": "1N"
  },
  "Gunderson High School": {
    "address": "622 Gundaer Dr, San Jose, CA 95136",
    "zone": "1N"
  },
  "Fremont High School Pool": {
    "address": "1279 Sunnyvale Saratoga Rd, Sunnyvale, CA 94087",
    "zone": "1N"
  },
  "Morgan Hill Aquatics Center": {
    "address": "16200 Condit Rd, Morgan Hill, CA 95037",
    "zone": "1S"
  },
  "Santa Clara Swim Center": {
    "address": "2625 Patricia Dr, Santa Clara, CA 95051",
    "zone": "1S"
  },
  "Aptos High School Pool": {
    "address": "100 Mariner Way, Aptos, CA 95003",
    "zone": "1S"
  },
  "Simpkins Family Swim Center": {
    "address": "979 17th Ave, Santa Cruz, CA 95062",
    "zone": "1S"
  },
  "Hartnell College Pool": {
    "address": "411 Central Ave, Salinas, CA 93901",
    "zone": "1S"
  },
  "Heritage High School (Seawolves)": {
    "address": "101 American Ave, Brentwood, CA 94513",
    "zone": "2"
  },
  "San Ramon Olympic Pool": {
    "address": "9900 Broadmoor Dr, San Ramon, CA 94583",
    "zone": "2"
  },
  "Concord Community Pool": {
    "address": "3501 Cowell Rd, Concord, CA 94518",
    "zone": "2"
  },
  "Las Positas College": {
    "address": "3000 Campus Hill Dr, Livermore, CA 94551",
    "zone": "2"
  },
  // Home pool for OAPB: commonly called "Soda Center"; on Campolindo HS campus, Moraga.
  "Soda Aquatic Center (Campolindo)": {
    "address": "300 Moraga Rd, Moraga, CA 94556",
    "soft_name": "Campolindo High School",
    "zone": "2"
  },
  "Soda Center": {
    "address": "300 Moraga Rd, Moraga, CA 94556",
    "soft_name": "Campolindo High School Moraga",
    "zone": "2"
  },
  "Tracy High School Pool": {
    "address": "315 E 11th St, Tracy, CA 95376",
    "zone": "2"
  },
  "Miwok Aquatic Center (IVC)": {
    "address": "1800 Ignacio Blvd, Novato, CA 94949",
    "zone": "3"
  },
  "Terra Linda Pool": {
    "address": "670 Del Ganado Rd, San Rafael, CA 94903",
    "zone": "3"
  },
  "Finley Aquatic Center": {
    "address": "2060 W College Ave, Santa Rosa, CA 95401",
    "zone": "3"
  },
  "Napa Valley College Pool": {
    "address": "2277 Napa Vallejo Hwy, Napa, CA 94558",
    "zone": "3"
  },
  "MLK Jr. Pool": {"address": "5701 3rd St, San Francisco, CA 94124", "zone": "3"},
  "Northwest Pool": {"address": "2925 Apollo Way, Reno, NV 89503", "zone": "4"},
  "Carson City Aquatic Facility": {
    "address": "841 N Roop St, Carson City, NV 89701",
    "zone": "4"
  },
  "Incline Village Rec Center": {
    "address": "980 Incline Way, Incline Village, NV 89451",
    "zone": "4"
  }
};

String slugifyVenueId(String input) {
  final slug = input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return slug.isEmpty ? 'unknown_venue' : slug;
}

/// Tokens for [arrayContainsAny] search (city, street words, venue name parts).
List<String> buildVenueKeywords(
  String name,
  String address, {
  String softName = '',
}) {
  final buf = StringBuffer()
    ..write(name)
    ..write(' ')
    ..write(address);
  if (softName.isNotEmpty) {
    buf.write(' ');
    buf.write(softName);
  }
  final set = buf
      .toString()
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.length >= 3)
      .toSet();
  return set.take(30).toList();
}

Future<void> hydrateVenuesCollection(FirebaseFirestore firestore) async {
  final batch = firestore.batch();
  final venuesRef = firestore.collection('venues');

  venueData.forEach((name, data) {
    final id = slugifyVenueId(name);
    final address = (data['address'] ?? '').trim();
    final zone = (data['zone'] ?? '').trim();
    final softName = (data['soft_name'] ?? '').trim();
    batch.set(
      venuesRef.doc(id),
      <String, dynamic>{
        'name': name,
        'address': address,
        'zone': zone,
        'search_name': name.toLowerCase(),
        'keywords': buildVenueKeywords(name, address, softName: softName),
        if (softName.isNotEmpty) 'soft_name': softName,
        'last_updated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  });

  await batch.commit();
}
