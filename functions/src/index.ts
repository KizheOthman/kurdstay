import { randomUUID } from "node:crypto";

import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import {
  DocumentReference,
  FieldValue,
  Timestamp,
  Transaction,
  getFirestore,
} from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

import { setGlobalOptions } from "firebase-functions/v2";
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  onDocumentUpdated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";

initializeApp();

setGlobalOptions({
  region: "europe-west1",
  maxInstances: 20,
});

const db = getFirestore();
const auth = getAuth();
const messaging = getMessaging();

type Role = "user" | "owner" | "admin";

function requireAuth(
  request: Parameters<Parameters<typeof onCall>[0]>[0],
): string {
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in.",
    );
  }

  return uid;
}

async function getRole(uid: string): Promise<Role> {
  const snapshot = await db.collection("users").doc(uid).get();

  if (!snapshot.exists) {
    throw new HttpsError(
      "failed-precondition",
      "User profile does not exist.",
    );
  }

  return (snapshot.data()?.role ?? "user") as Role;
}

function parseDate(input: unknown, field: string): Date {
  if (typeof input !== "string") {
    throw new HttpsError(
      "invalid-argument",
      `${field} must be an ISO date string.`,
    );
  }

  const date = new Date(input);

  if (Number.isNaN(date.getTime())) {
    throw new HttpsError(
      "invalid-argument",
      `${field} is invalid.`,
    );
  }

  return new Date(
    Date.UTC(
      date.getUTCFullYear(),
      date.getUTCMonth(),
      date.getUTCDate(),
    ),
  );
}

function dateKey(date: Date): string {
  return [
    date.getUTCFullYear(),
    String(date.getUTCMonth() + 1).padStart(2, "0"),
    String(date.getUTCDate()).padStart(2, "0"),
  ].join("");
}

function datesBetween(checkIn: Date, checkOut: Date): Date[] {
  const nights =
    (checkOut.getTime() - checkIn.getTime()) /
    (24 * 60 * 60 * 1000);

  if (nights < 1 || nights > 30) {
    throw new HttpsError(
      "invalid-argument",
      "Bookings must be between 1 and 30 nights.",
    );
  }

  const result: Date[] = [];

  for (
    let date = new Date(checkIn);
    date < checkOut;
    date = new Date(date.getTime() + 24 * 60 * 60 * 1000)
  ) {
    result.push(date);
  }

  return result;
}

function inventoryReference(
  hotelId: string,
  roomId: string,
  date: Date,
): DocumentReference {
  return db
    .collection("roomInventory")
    .doc(`${hotelId}_${roomId}_${dateKey(date)}`);
}

async function createBookingRecord(args: {
  authenticatedUid: string;
  hotelId: string;
  roomId: string;
  checkIn: Date;
  checkOut: Date;
  guests: number;
  specialRequests: string;
  paymentMethod: string;
  createdBy: "user" | "owner" | "admin";
  guestName?: string;
  guestEmail?: string;
  guestPhone?: string;
  userId?: string | null;
}): Promise<string> {
  const {
    authenticatedUid,
    hotelId,
    roomId,
    checkIn,
    checkOut,
    guests,
    specialRequests,
    paymentMethod,
    createdBy,
  } = args;

  const stayDates = datesBetween(checkIn, checkOut);
  const bookingReference = db.collection("bookings").doc();

  const hotelReference = db.collection("hotels").doc(hotelId);
  const roomReference = hotelReference.collection("rooms").doc(roomId);

  await db.runTransaction(async (transaction) => {
  // ---------------------------------------------------------
  // 1. ALL READS MUST HAPPEN BEFORE ANY WRITES
  // ---------------------------------------------------------

  const hotelSnapshot = await transaction.get(hotelReference);
  const roomSnapshot = await transaction.get(roomReference);

  if (!hotelSnapshot.exists) {
    throw new HttpsError("not-found", "Hotel not found.");
  }

  if (!roomSnapshot.exists) {
    throw new HttpsError("not-found", "Room not found.");
  }

  const hotel = hotelSnapshot.data()!;
  const room = roomSnapshot.data()!;

  if (hotel.active !== true || room.active !== true) {
    throw new HttpsError(
      "failed-precondition",
      "The selected hotel or room is inactive.",
    );
  }

  /*
   * createManualBooking already verifies that the caller is
   * either an owner or an administrator before this function runs.
   */
  if (
    createdBy !== "user" &&
    hotel.ownerId !== authenticatedUid &&
    createdBy !== "admin"
  ) {
    throw new HttpsError(
      "permission-denied",
      "You cannot create a booking for this hotel.",
    );
  }

  const capacity = Number(room.capacity ?? 1);

  if (guests < 1 || guests > capacity) {
    throw new HttpsError(
      "invalid-argument",
      `This room supports up to ${capacity} guests.`,
    );
  }

  const inventoryReferences = stayDates.map((date) =>
    inventoryReference(hotelId, roomId, date),
  );

  // Read all inventory documents.
  const inventorySnapshots = await Promise.all(
    inventoryReferences.map((reference) =>
      transaction.get(reference),
    ),
  );

  // Read the authenticated user's profile before any writes.
  const userReference = db
    .collection("users")
    .doc(authenticatedUid);

  const userSnapshot = await transaction.get(userReference);

  // ---------------------------------------------------------
  // 2. PROCESS AND VALIDATE THE READ DATA
  // ---------------------------------------------------------

  const totalRooms = Number(room.totalRooms ?? 1);

  inventorySnapshots.forEach((snapshot) => {
    const bookedCount = Number(
      snapshot.data()?.bookedCount ?? 0,
    );

    if (bookedCount >= totalRooms) {
      throw new HttpsError(
        "already-exists",
        "The room is unavailable for one or more selected nights.",
      );
    }
  });

  const authenticatedProfile = userSnapshot.data() ?? {};

  const userId =
    args.userId !== undefined
      ? args.userId
      : createdBy === "user"
        ? authenticatedUid
        : null;

  const guestName =
    args.guestName ??
    authenticatedProfile.name ??
    "KurdStay guest";

  const guestEmail =
    args.guestEmail ??
    authenticatedProfile.email ??
    "";

  const guestPhone =
    args.guestPhone ??
    authenticatedProfile.phone ??
    "";

  const pricePerNight = Number(room.pricePerNight ?? 0);
  const totalPrice = pricePerNight * stayDates.length;
  const qrToken = randomUUID();

  // ---------------------------------------------------------
  // 3. ALL WRITES HAPPEN AFTER ALL READS
  // ---------------------------------------------------------

  inventoryReferences.forEach((reference, index) => {
    const snapshot = inventorySnapshots[index];

    const currentBookedCount = Number(
      snapshot.data()?.bookedCount ?? 0,
    );

    transaction.set(
      reference,
      {
        hotelId,
        roomId,
        dateKey: dateKey(stayDates[index]),
        bookedCount: currentBookedCount + 1,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });

  transaction.create(bookingReference, {
    hotelId,
    hotelName: hotel.name,
    roomId,
    roomName: room.name,
    ownerId: hotel.ownerId,
    userId,
    guestName,
    guestEmail,
    guestPhone,
    checkIn: Timestamp.fromDate(checkIn),
    checkOut: Timestamp.fromDate(checkOut),
    guests,
    nights: stayDates.length,
    pricePerNight,
    totalPrice,
    status: createdBy === "user" ? "pending" : "confirmed",
    qrToken,
    qrUsed: false,
    inventoryKeys: inventoryReferences.map(
      (reference) => reference.id,
    ),
    inventoryReleased: false,
    specialRequests,
    paymentMethod,
    createdBy,
    createdByUid: authenticatedUid,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
});

  return bookingReference.id;
}

export const createBooking = onCall(async (request) => {
  try {
    const uid = requireAuth(request);
    const data = request.data ?? {};

    const bookingId = await createBookingRecord({
      authenticatedUid: uid,
      hotelId: String(data.hotelId ?? ""),
      roomId: String(data.roomId ?? ""),
      checkIn: parseDate(data.checkIn, "checkIn"),
      checkOut: parseDate(data.checkOut, "checkOut"),
      guests: Number(data.guests ?? 1),
      specialRequests: String(
        data.specialRequests ?? "",
      ),
      paymentMethod: String(
        data.paymentMethod ?? "pay_at_hotel",
      ),
      createdBy: "user",
    });

    return { bookingId };
  } catch (error) {
    console.error("createBooking failed:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError(
      "internal",
      "The booking could not be created. Check the function logs.",
    );
  }
});

export const createManualBooking = onCall(async (request) => {
  const uid = requireAuth(request);
  const role = await getRole(uid);

  if (role !== "owner" && role !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Only hotel owners and administrators can create manual bookings.",
    );
  }

  const data = request.data ?? {};

  const bookingId = await createBookingRecord({
    authenticatedUid: uid,
    hotelId: String(data.hotelId ?? ""),
    roomId: String(data.roomId ?? ""),
    checkIn: parseDate(data.checkIn, "checkIn"),
    checkOut: parseDate(data.checkOut, "checkOut"),
    guests: Number(data.guests ?? 1),
    specialRequests: String(data.specialRequests ?? ""),
    paymentMethod: String(data.paymentMethod ?? "pay_at_hotel"),
    createdBy: role,
    guestName: String(data.guestName ?? ""),
    guestEmail: String(data.guestEmail ?? ""),
    guestPhone: String(data.guestPhone ?? ""),
    userId: null,
  });

  return { bookingId };
});

async function releaseInventory(
  transaction: Transaction,
  inventoryKeys: string[],
): Promise<void> {
  const references = inventoryKeys.map((key) =>
    db.collection("roomInventory").doc(key),
  );

  const snapshots = await Promise.all(
    references.map((reference) => transaction.get(reference)),
  );

  references.forEach((reference, index) => {
    const current = Number(
      snapshots[index].data()?.bookedCount ?? 0,
    );

    transaction.set(
      reference,
      {
        bookedCount: Math.max(0, current - 1),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

export const updateBookingStatus = onCall(async (request) => {
  const uid = requireAuth(request);
  const role = await getRole(uid);

  if (role !== "owner" && role !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Only an owner or administrator may change booking status.",
    );
  }

  const bookingId = String(request.data?.bookingId ?? "");
  const nextStatus = String(request.data?.status ?? "");

  const allowedStatuses = [
    "pending",
    "confirmed",
    "checkedIn",
    "completed",
    "cancelled",
  ];

  if (!allowedStatuses.includes(nextStatus)) {
    throw new HttpsError(
      "invalid-argument",
      "Unsupported booking status.",
    );
  }

  const reference = db.collection("bookings").doc(bookingId);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);

    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }

    const booking = snapshot.data()!;

    if (
      role !== "admin" &&
      booking.ownerId !== uid
    ) {
      throw new HttpsError(
        "permission-denied",
        "This booking does not belong to your hotel.",
      );
    }

    if (
      nextStatus === "cancelled" &&
      booking.inventoryReleased !== true
    ) {
      await releaseInventory(
        transaction,
        (booking.inventoryKeys ?? []) as string[],
      );
    }

    transaction.update(reference, {
      status: nextStatus,
      inventoryReleased:
        nextStatus === "cancelled"
          ? true
          : booking.inventoryReleased ?? false,
      updatedAt: FieldValue.serverTimestamp(),
      [`${nextStatus}At`]: FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});

export const cancelBooking = onCall(async (request) => {
  const uid = requireAuth(request);
  const bookingId = String(request.data?.bookingId ?? "");
  const reference = db.collection("bookings").doc(bookingId);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);

    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }

    const booking = snapshot.data()!;

    if (booking.userId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "You cannot cancel this booking.",
      );
    }

    if (!["pending", "confirmed"].includes(booking.status)) {
      throw new HttpsError(
        "failed-precondition",
        "This booking can no longer be cancelled.",
      );
    }

    if (booking.inventoryReleased !== true) {
      await releaseInventory(
        transaction,
        (booking.inventoryKeys ?? []) as string[],
      );
    }

    transaction.update(reference, {
      status: "cancelled",
      inventoryReleased: true,
      cancelledAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});

export const rescheduleBooking = onCall(async (request) => {
  const uid = requireAuth(request);
  const bookingId = String(request.data?.bookingId ?? "");
  const newCheckIn = parseDate(request.data?.checkIn, "checkIn");
  const newCheckOut = parseDate(request.data?.checkOut, "checkOut");
  const newDates = datesBetween(newCheckIn, newCheckOut);

  const bookingReference =
    db.collection("bookings").doc(bookingId);

  await db.runTransaction(async (transaction) => {
    const bookingSnapshot =
      await transaction.get(bookingReference);

    if (!bookingSnapshot.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }

    const booking = bookingSnapshot.data()!;

    if (booking.userId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "You cannot reschedule this booking.",
      );
    }

    if (!["pending", "confirmed"].includes(booking.status)) {
      throw new HttpsError(
        "failed-precondition",
        "This booking cannot be rescheduled.",
      );
    }

    const roomReference = db
      .collection("hotels")
      .doc(booking.hotelId)
      .collection("rooms")
      .doc(booking.roomId);

    const roomSnapshot = await transaction.get(roomReference);

    if (!roomSnapshot.exists) {
      throw new HttpsError("not-found", "Room not found.");
    }

    const totalRooms = Number(
      roomSnapshot.data()?.totalRooms ?? 1,
    );

    const oldKeys =
      (booking.inventoryKeys ?? []) as string[];

    const newReferences = newDates.map((date) =>
      inventoryReference(
        booking.hotelId,
        booking.roomId,
        date,
      ),
    );

    const newKeys = newReferences.map((reference) => reference.id);

    const deltas = new Map<string, number>();

    oldKeys.forEach((key) => {
      deltas.set(key, (deltas.get(key) ?? 0) - 1);
    });

    newKeys.forEach((key) => {
      deltas.set(key, (deltas.get(key) ?? 0) + 1);
    });

    const references = [...deltas.keys()].map((key) =>
      db.collection("roomInventory").doc(key),
    );

    const snapshots = await Promise.all(
      references.map((reference) =>
        transaction.get(reference),
      ),
    );

    references.forEach((reference, index) => {
      const snapshot = snapshots[index];
      const current = Number(
        snapshot.data()?.bookedCount ?? 0,
      );
      const next =
        current + (deltas.get(reference.id) ?? 0);

      if (next > totalRooms) {
        throw new HttpsError(
          "already-exists",
          "The room is unavailable for the selected dates.",
        );
      }

      transaction.set(
        reference,
        {
          hotelId: booking.hotelId,
          roomId: booking.roomId,
          dateKey: reference.id.split("_").pop(),
          bookedCount: Math.max(0, next),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });

    const nights = newDates.length;
    const totalPrice =
      Number(booking.pricePerNight ?? 0) * nights;

    transaction.update(bookingReference, {
      checkIn: Timestamp.fromDate(newCheckIn),
      checkOut: Timestamp.fromDate(newCheckOut),
      nights,
      totalPrice,
      inventoryKeys: newKeys,
      status: "pending",
      updatedAt: FieldValue.serverTimestamp(),
      rescheduledAt: FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});

export const verifyBookingQr = onCall(async (request) => {
  const uid = requireAuth(request);
  const role = await getRole(uid);

  if (role !== "owner" && role !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Only hotel staff may scan booking codes.",
    );
  }

  let payload: {
    app?: string;
    bookingId?: string;
    token?: string;
  };

  try {
    payload = JSON.parse(String(request.data?.qrData ?? ""));
  } catch {
    throw new HttpsError(
      "invalid-argument",
      "The QR data is not valid.",
    );
  }

  if (
    payload.app !== "kurdstay" ||
    !payload.bookingId ||
    !payload.token
  ) {
    throw new HttpsError(
      "invalid-argument",
      "This is not a KurdStay booking QR.",
    );
  }

  const reference =
    db.collection("bookings").doc(payload.bookingId);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);

    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }

    const booking = snapshot.data()!;

    if (
      role !== "admin" &&
      booking.ownerId !== uid
    ) {
      throw new HttpsError(
        "permission-denied",
        "This booking belongs to another hotel.",
      );
    }

    if (booking.qrToken !== payload.token) {
      throw new HttpsError(
        "permission-denied",
        "The QR security token is invalid.",
      );
    }

    if (booking.qrUsed === true) {
      throw new HttpsError(
        "already-exists",
        "This QR code has already been used.",
      );
    }

    if (booking.status !== "confirmed") {
      throw new HttpsError(
        "failed-precondition",
        "Only confirmed bookings can be checked in.",
      );
    }

    transaction.update(reference, {
      status: "checkedIn",
      qrUsed: true,
      qrUsedAt: FieldValue.serverTimestamp(),
      checkedInAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  const updated = await reference.get();
  const booking = updated.data()!;

  return {
    success: true,
    guestName: booking.guestName,
    hotelName: booking.hotelName,
    roomName: booking.roomName,
  };
});

export const setUserRole = onCall(async (request) => {
  const adminUid = requireAuth(request);
  const adminRole = await getRole(adminUid);

  if (adminRole !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Only administrators may assign roles.",
    );
  }

  const userId = String(request.data?.userId ?? "");
  const role = String(request.data?.role ?? "") as Role;

  if (!["user", "owner", "admin"].includes(role)) {
    throw new HttpsError(
      "invalid-argument",
      "Unsupported role.",
    );
  }

  if (userId === adminUid && role !== "admin") {
    throw new HttpsError(
      "failed-precondition",
      "You cannot remove your own administrator role.",
    );
  }

  await auth.setCustomUserClaims(userId, { role });

  await db.collection("users").doc(userId).update({
    role,
    updatedAt: FieldValue.serverTimestamp(),
    roleUpdatedBy: adminUid,
  });

  return { success: true };
});

export const notifyBookingStatusChanged =
  onDocumentUpdated(
    "bookings/{bookingId}",
    async (event) => {
      const before = event.data?.before.data();
      const after = event.data?.after.data();

      if (!before || !after || before.status === after.status) {
        return;
      }

      const userIds = [
        after.userId,
        after.ownerId,
      ].filter(
        (value): value is string =>
          typeof value === "string" && value.length > 0,
      );

      for (const userId of userIds) {
        const userSnapshot =
          await db.collection("users").doc(userId).get();

        const tokens =
          (userSnapshot.data()?.fcmTokens ?? []) as string[];

        const title = "Booking updated";
        const body =
          `${after.hotelName}: booking is now ${after.status}.`;

        await db
          .collection("notifications")
          .doc(userId)
          .collection("items")
          .add({
            title,
            body,
            bookingId: event.params.bookingId,
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          });

        if (tokens.length > 0) {
          await messaging.sendEachForMulticast({
            tokens,
            notification: { title, body },
            data: {
              bookingId: event.params.bookingId,
              status: String(after.status),
            },
            android: {
              priority: "high",
              notification: {
                channelId: "booking_updates",
              },
            },
          });
        }
      }
    },
  );

export const recomputeHotelRating =
  onDocumentWritten(
    "reviews/{reviewId}",
    async (event) => {
      const data =
        event.data?.after.data() ??
        event.data?.before.data();

      const hotelId = data?.hotelId as string | undefined;

      if (!hotelId) return;

      const reviewsSnapshot = await db
        .collection("reviews")
        .where("hotelId", "==", hotelId)
        .get();

      const ratings = reviewsSnapshot.docs.map(
        (document) =>
          Number(document.data().rating ?? 0),
      );

      const average =
        ratings.length === 0
          ? 0
          : ratings.reduce((sum, value) => sum + value, 0) /
            ratings.length;

      await db.collection("hotels").doc(hotelId).update({
        ratingAverage:
          Math.round(average * 10) / 10,
        reviewCount: ratings.length,
        updatedAt: FieldValue.serverTimestamp(),
      });
    },
  );