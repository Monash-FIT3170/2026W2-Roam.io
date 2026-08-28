/*
 * Description:
 *   Seeds the global Firestore `quests` collection with initial Roam.io
 *   side quests.
 *
 *   Quest definitions are shared across all users.
 *   User-specific progress is stored separately under:
 *
 *   profiles/{userId}/quests/{questId}
 *
 *   Running this script is safe multiple times because each quest uses a
 *   fixed document ID and is written with merge: true.
 */

const admin = require('firebase-admin');

const PROJECT_ID = 'roam-io-71e2c';

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: PROJECT_ID,
});

const db = admin.firestore();

const quests = [
  {
    id: 'melbourne_museum_explorer',

    title: 'Melbourne Museum Explorer',

    description:
      'Visit Melbourne Museum and explore one of Melbourne’s major cultural landmarks.',

    category: 'culture',
    difficulty: 'easy',
    rewardXp: 250,

    verificationType: 'gps',
    isActive: true,

    latitude: -37.8033,
    longitude: 144.9717,
    verificationRadiusMetres: 180,

    estimatedMinutes: 60,

    regionId: null,
    placeId: null,
    imageUrl: null,

    availableFrom: null,
    availableUntil: null,
  },

  {
    id: 'sea_life_underwater_explorer',

    title: 'Underwater Explorer',

    description:
      'Visit SEA LIFE Melbourne Aquarium and discover Melbourne’s underwater world.',

    category: 'adventure',
    difficulty: 'easy',
    rewardXp: 300,

    verificationType: 'gpsAndPhoto',
    isActive: true,

    latitude: -37.8206,
    longitude: 144.9585,
    verificationRadiusMetres: 180,

    estimatedMinutes: 90,

    regionId: null,
    placeId: null,
    imageUrl: null,

    availableFrom: null,
    availableUntil: null,
  },

  {
    id: 'kokoda_1000_steps',

    title: 'Conquer the 1000 Steps',

    description:
      'Complete the Kokoda Track Memorial Walk through the Dandenong Ranges and conquer the famous 1000 Steps.',

    category: 'fitness',
    difficulty: 'hard',
    rewardXp: 500,

    verificationType: 'gpsAndPhoto',
    isActive: true,

    latitude: -37.8840,
    longitude: 145.3125,
    verificationRadiusMetres: 300,

    estimatedMinutes: 90,

    regionId: null,
    placeId: null,
    imageUrl: null,

    availableFrom: null,
    availableUntil: null,
  },

  {
    id: 'skyhigh_dandenong_snap',

    title: 'Dandenong Lookout Snap',

    description:
      'Reach the SkyHigh Mount Dandenong area and capture a photo overlooking Melbourne and the surrounding ranges.',

    category: 'photography',
    difficulty: 'medium',
    rewardXp: 350,

    verificationType: 'gpsAndPhoto',
    isActive: true,

    latitude: -37.8271,
    longitude: 145.3528,
    verificationRadiusMetres: 250,

    estimatedMinutes: 45,

    regionId: null,
    placeId: null,
    imageUrl: null,

    availableFrom: null,
    availableUntil: null,
  },

  {
    id: 'royal_botanic_gardens',

    title: 'Garden Wanderer',

    description:
      'Explore Melbourne’s Royal Botanic Gardens and spend some time wandering through the gardens.',

    category: 'nature',
    difficulty: 'easy',
    rewardXp: 200,

    verificationType: 'gps',
    isActive: true,

    latitude: -37.8304,
    longitude: 144.9796,
    verificationRadiusMetres: 300,

    estimatedMinutes: 45,

    regionId: null,
    placeId: null,
    imageUrl: null,

    availableFrom: null,
    availableUntil: null,
  },

  {
    id: 'state_library_discovery',

    title: 'State Library Discovery',

    description:
      'Visit the State Library of Victoria and explore one of Melbourne’s most recognisable public spaces.',

    category: 'history',
    difficulty: 'easy',
    rewardXp: 200,

    verificationType: 'gps',
    isActive: true,

    latitude: -37.8098,
    longitude: 144.9652,
    verificationRadiusMetres: 160,

    estimatedMinutes: 40,

    regionId: null,
    placeId: null,
    imageUrl: null,

    availableFrom: null,
    availableUntil: null,
  },

  {
    id: 'brighton_bathing_boxes',

    title: 'Brighton Bathing Boxes',

    description:
      'Visit the colourful Brighton Bathing Boxes and capture a photo from the beachfront.',

    category: 'photography',
    difficulty: 'easy',
    rewardXp: 300,

    verificationType: 'gpsAndPhoto',
    isActive: true,

    latitude: -37.9180,
    longitude: 144.9866,
    verificationRadiusMetres: 220,

    estimatedMinutes: 40,

    regionId: null,
    placeId: null,
    imageUrl: null,

    availableFrom: null,
    availableUntil: null,
  },

  {
    id: 'queen_victoria_market',

    title: 'Market Explorer',

    description:
      'Visit Queen Victoria Market and explore one of Melbourne’s best-known markets.',

    category: 'food',
    difficulty: 'easy',
    rewardXp: 200,

    verificationType: 'gps',
    isActive: true,

    latitude: -37.8076,
    longitude: 144.9568,
    verificationRadiusMetres: 200,

    estimatedMinutes: 45,

    regionId: null,
    placeId: null,
    imageUrl: null,

    availableFrom: null,
    availableUntil: null,
  },
];

async function seedQuests() {
  console.log(`Seeding ${quests.length} quests into Firestore...`);
  console.log(`Project: ${PROJECT_ID}`);

  const batch = db.batch();

  for (const quest of quests) {
    const { id, ...questData } = quest;

    const reference = db.collection('quests').doc(id);

    batch.set(
      reference,
      {
        ...questData,

        // Useful metadata for administration later.
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      },
    );

    console.log(`Prepared quest: ${id}`);
  }

  await batch.commit();

  console.log('');
  console.log(`Successfully seeded ${quests.length} quests.`);
  console.log('Collection: quests');
}

seedQuests()
  .then(() => {
    console.log('Done.');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Quest seed failed:');
    console.error(error);
    process.exit(1);
  });