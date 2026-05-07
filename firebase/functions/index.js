const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.onUserDeleted = functions.auth.user().onDelete(async () => {
  return null;
});

function trimString(value) {
  return value == null ? "" : String(value).trim();
}

function firstNonEmptyString(data, keys) {
  for (const key of keys) {
    const value = trimString(data[key]);
    if (value.length > 0 && value !== "null") {
      return value;
    }
  }
  return "";
}

function meetTitle(data, fallbackId) {
  return firstNonEmptyString(data, ["title", "meet_name", "meetName", "name"]) ||
    fallbackId ||
    "this meet";
}

function entryUrlFromMeetData(data, meetId) {
  const explicit = firstNonEmptyString(data, [
    "entry_url",
    "entryUrl",
    "EntryUrl",
  ]);
  if (explicit) {
    return explicit;
  }
  const id = firstNonEmptyString(data, ["meet_id", "meetId", "MeetId"]) ||
    meetId;
  return /^\d+$/.test(id) ?
    `https://ome.fastswims.com/meets/${id}/enter` :
    "";
}

function signupIsOpen(data, meetId) {
  const status = trimString(data.status || data.status_detail ||
    data.statusDetail)
    .toLowerCase();
  return status !== "pending" && entryUrlFromMeetData(data, meetId).length > 0;
}

/**
 * Monitored meets pipeline (hourly job + coach email):
 * - Set `coach_approved: true` when the meet is cited in a parsed coach email.
 * - The Flutter client surfaces this as a "Coach approved" chip and boosts Agent priority.
 * - When signup opens (`signupIsOpen`), urgent ranking matches volunteer signup openings.
 */

exports.onMonitoredMeetSignupOpened = functions.firestore
  .document("monitored_meets/{meetId}")
  .onWrite(async (change, context) => {
    if (!change.after.exists) {
      return null;
    }

    const meetId = context.params.meetId;
    const beforeOpen = change.before.exists &&
      signupIsOpen(change.before.data() || {}, meetId);
    const afterData = change.after.data() || {};
    const afterOpen = signupIsOpen(afterData, meetId);
    if (!afterOpen || beforeOpen) {
      return null;
    }

    const firestore = admin.firestore();
    const prefs = await firestore
      .collectionGroup("meet_preferences")
      .where("has_alert", "==", true)
      .get();
    if (prefs.empty) {
      return null;
    }

    const title = meetTitle(afterData, meetId);
    const entryUrl = entryUrlFromMeetData(afterData, meetId);
    const tasks = [];

    prefs.forEach((prefDoc) => {
      const pref = prefDoc.data() || {};
      if (prefDoc.id !== meetId || pref.status !== "need_entry") {
        return;
      }

      const userRef = prefDoc.ref.parent.parent;
      if (!userRef) {
        return;
      }

      tasks.push((async () => {
        const userSnap = await userRef.get();
        const token = trimString((userSnap.data() || {}).fcm_token);
        if (!token) {
          await prefDoc.ref.set({
            signup_open_alert_error: "missing_fcm_token",
            signup_open_alert_checked_at:
              admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          return;
        }

        try {
          await admin.messaging().send({
            token,
            notification: {
              title: "FastSwim is open",
              body: `${title} is open for entries.`,
            },
            data: {
              type: "meet_signup_open",
              meetId,
              entryUrl,
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                },
              },
            },
          });
          await prefDoc.ref.set({
            has_alert: false,
            signup_open_alert_sent_at:
              admin.firestore.FieldValue.serverTimestamp(),
            signup_open_alert_entry_url: entryUrl,
            signup_open_alert_error: admin.firestore.FieldValue.delete(),
          }, { merge: true });
        } catch (err) {
          const code = err && err.code ? String(err.code) : "send_failed";
          const update = {
            signup_open_alert_error: code,
            signup_open_alert_checked_at:
              admin.firestore.FieldValue.serverTimestamp(),
          };
          if (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
          ) {
            update.has_alert = false;
            await userRef.set({
              fcm_token: admin.firestore.FieldValue.delete(),
              fcm_token_invalidated_at:
                admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
          }
          await prefDoc.ref.set(update, { merge: true });
        }
      })());
    });

    await Promise.all(tasks);
    return null;
  });
