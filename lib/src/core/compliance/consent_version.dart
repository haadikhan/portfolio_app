/// Bumping this value invalidates prior consent documents in Firestore so users
/// must accept the updated legal text again (see [FirestoreService.persistConsent]).
const String kConsentDocumentVersion = "v2";
