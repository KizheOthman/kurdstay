import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import {
  FieldValue,
  GeoPoint,
  getFirestore,
} from "firebase-admin/firestore";
import * as admin from "firebase-admin";
import serviceAccount from "../serviceAccountKey.json";

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount as admin.ServiceAccount),
});


const auth = getAuth();
const db = getFirestore();

async function ensureUser(args: {
  email: string;
  password: string;
  name: string;
  phone: string;
  role: "user" | "owner" | "admin";
}) {
  let user;

  try {
    user = await auth.getUserByEmail(args.email);
  } catch {
    user = await auth.createUser({
      email: args.email,
      password: args.password,
      displayName: args.name,
      emailVerified: true,
    });
  }

  await auth.setCustomUserClaims(user.uid, {
    role: args.role,
  });

  await db.collection("users").doc(user.uid).set(
    {
      name: args.name,
      email: args.email,
      phone: args.phone,
      role: args.role,
      active: true,
      fcmTokens: [],
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return user.uid;
}

async function createHotel(args: {
  id: string;
  ownerId: string;
  name: string;
  description: string;
  city: string;
  address: string;
  latitude: number;
  longitude: number;
  images: string[];
  amenities: string[];
  featured: boolean;
  rooms: Array<{
    id: string;
    name: string;
    type: string;
    price: number;
    capacity: number;
    totalRooms: number;
  }>;
}) {
  const minimumPrice = Math.min(
    ...args.rooms.map((room) => room.price),
  );

  await db.collection("hotels").doc(args.id).set({
    ownerId: args.ownerId,
    name: args.name,
    description: args.description,
    city: args.city,
    address: args.address,
    location: new GeoPoint(
      args.latitude,
      args.longitude,
      
    ),
    images: args.images,
    amenities: args.amenities,
    minimumPrice,
    ratingAverage: 0,
    reviewCount: 0,
    active: true,
    featured: args.featured,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    deleted: false,
  });

  for (const room of args.rooms) {
    await db
      .collection("hotels")
      .doc(args.id)
      .collection("rooms")
      .doc(room.id)
      .set({
        hotelId: args.id,
        name: room.name,
        type: room.type,
        description:
          `Comfortable ${room.type.toLowerCase()} room with modern facilities.`,
        pricePerNight: room.price,
        capacity: room.capacity,
        totalRooms: room.totalRooms,
        images: args.images.slice(0, 1),
        amenities: [
          "Private bathroom",
          "Air conditioning",
          "Free Wi-Fi",
          "Television"
        ],
        active: true,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
  }
}

async function main() {
  const adminId = await ensureUser({
    email: "admin@kurdstay.demo",
    password: "Admin12345!",
    name: "KurdStay Administrator",
    phone: "+964 770 000 0001",
    role: "admin",
  });

  const ownerOneId = await ensureUser({
    email: "owner1@kurdstay.demo",
    password: "Owner12345!",
    name: "Soran Hotel Group",
    phone: "+964 770 000 0002",
    role: "owner",
  });

  const ownerTwoId = await ensureUser({
    email: "owner2@kurdstay.demo",
    password: "Owner12345!",
    name: "Zagros Hospitality",
    phone: "+964 750 000 0003",
    role: "owner",
  });

  await ensureUser({
    email: "user@kurdstay.demo",
    password: "User12345!",
    name: "Demo Traveller",
    phone: "+964 770 000 0004",
    role: "user",
  });

  const imageSets = {
    city: [
      "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=1400",
      "https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=1400",
      "https://images.unsplash.com/photo-1564501049412-61c2a3083791?w=1400"
    ],
    mountain: [
      "https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=1400",
      "https://images.unsplash.com/photo-1506059612708-99d6c258160e?w=1400",
      "https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=1400"
    ],
    resort: [
      "https://images.unsplash.com/photo-1540541338287-41700207dee6?w=1400",
      "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=1400",
      "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=1400"
    ]
  };

  await createHotel({
    id: "suli_grand",
    ownerId: ownerOneId,
    name: "Suli Grand Hotel",
    description:
      "A modern city hotel close to shopping, restaurants and central Sulaymaniyah attractions.",
    city: "Sulaymaniyah",
    address: "Salim Street, Sulaymaniyah",
    latitude: 35.5613,
    longitude: 45.4309,
    images: imageSets.city,
    amenities: [
      "Free Wi-Fi",
      "Parking",
      "Breakfast",
      "Restaurant",
      "Gym",
      "24-hour reception"
    ],
    featured: true,
    rooms: [
      {
        id: "standard",
        name: "Standard King Room",
        type: "Standard",
        price: 85000,
        capacity: 2,
        totalRooms: 8
      },
      {
        id: "family",
        name: "Family Room",
        type: "Family",
        price: 145000,
        capacity: 4,
        totalRooms: 4
      },
      {
        id: "suite",
        name: "Panorama Suite",
        type: "Suite",
        price: 220000,
        capacity: 3,
        totalRooms: 3
      }
    ]
  });

  await createHotel({
    id: "citadel_suites",
    ownerId: ownerOneId,
    name: "Citadel View Suites",
    description:
      "Comfortable suites with convenient access to Erbil city centre and the historic citadel area.",
    city: "Erbil",
    address: "Citadel District, Erbil",
    latitude: 36.1911,
    longitude: 44.0092,
    images: imageSets.city,
    amenities: [
      "Free Wi-Fi",
      "Breakfast",
      "Airport transfer",
      "Family rooms",
      "24-hour reception"
    ],
    featured: true,
    rooms: [
      {
        id: "double",
        name: "City Double Room",
        type: "Double",
        price: 95000,
        capacity: 2,
        totalRooms: 10
      },
      {
        id: "executive",
        name: "Executive Suite",
        type: "Suite",
        price: 190000,
        capacity: 3,
        totalRooms: 4
      }
    ]
  });

  await createHotel({
    id: "duhok_mountain",
    ownerId: ownerTwoId,
    name: "Duhok Mountain View",
    description:
      "A quiet hillside hotel offering mountain views, family rooms and easy access to Duhok.",
    city: "Duhok",
    address: "Zawa Mountain Road, Duhok",
    latitude: 36.8620,
    longitude: 42.9862,
    images: imageSets.mountain,
    amenities: [
      "Parking",
      "Restaurant",
      "Family rooms",
      "Free Wi-Fi",
      "Accessibility"
    ],
    featured: false,
    rooms: [
      {
        id: "mountain",
        name: "Mountain View Room",
        type: "Deluxe",
        price: 110000,
        capacity: 2,
        totalRooms: 7
      },
      {
        id: "family",
        name: "Mountain Family Suite",
        type: "Family suite",
        price: 180000,
        capacity: 5,
        totalRooms: 3
      }
    ]
  });

  await createHotel({
    id: "halabja_garden",
    ownerId: ownerTwoId,
    name: "Halabja Garden Hotel",
    description:
      "A peaceful garden-style property suitable for families and visitors exploring Halabja.",
    city: "Halabja",
    address: "Central Garden District, Halabja",
    latitude: 35.1778,
    longitude: 45.9861,
    images: imageSets.resort,
    amenities: [
      "Garden",
      "Parking",
      "Breakfast",
      "Family rooms",
      "Restaurant"
    ],
    featured: false,
    rooms: [
      {
        id: "garden",
        name: "Garden Double Room",
        type: "Double",
        price: 70000,
        capacity: 2,
        totalRooms: 6
      },
      {
        id: "family",
        name: "Garden Family Room",
        type: "Family",
        price: 125000,
        capacity: 4,
        totalRooms: 4
      }
    ]
  });

  await createHotel({
    id: "rawanduz_lodge",
    ownerId: ownerTwoId,
    name: "Rawanduz Canyon Lodge",
    description:
      "A scenic lodge designed for travellers visiting the mountains and canyon areas around Rawanduz.",
    city: "Rawanduz",
    address: "Canyon Road, Rawanduz",
    latitude: 36.6163,
    longitude: 44.5354,
    images: imageSets.mountain,
    amenities: [
      "Mountain views",
      "Parking",
      "Restaurant",
      "Breakfast",
      "Airport transfer"
    ],
    featured: true,
    rooms: [
      {
        id: "lodge",
        name: "Canyon Lodge Room",
        type: "Deluxe",
        price: 120000,
        capacity: 2,
        totalRooms: 8
      },
      {
        id: "chalet",
        name: "Family Chalet",
        type: "Chalet",
        price: 240000,
        capacity: 6,
        totalRooms: 3
      }
    ]
  });

  console.log("Seed completed.");
  console.log("Administrator UID:", adminId);
  console.log("Admin: admin@kurdstay.demo / Admin12345!");
  console.log("Owner: owner1@kurdstay.demo / Owner12345!");
  console.log("Owner: owner2@kurdstay.demo / Owner12345!");
  console.log("User: user@kurdstay.demo / User12345!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });