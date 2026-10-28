import "dart:convert";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;

/// Session debug ingest (admin / investor balance audit). Debug builds only.
void agentDebugLog({
  required String location,
  required String message,
  required Map<String, Object?> data,
  String hypothesisId = "",
  String runId = "pre-fix",
}) {
  if (!kDebugMode) return;
  // #region agent log
  http
      .post(
        Uri.parse(
          "http://127.0.0.1:7783/ingest/63e8c135-e261-4b69-9d31-06b3354cac8d",
        ),
        headers: {
          "Content-Type": "application/json",
          "X-Debug-Session-Id": "16fd4a",
        },
        body: jsonEncode({
          "sessionId": "16fd4a",
          "location": location,
          "message": message,
          "data": data,
          "hypothesisId": hypothesisId,
          "runId": runId,
          "timestamp": DateTime.now().millisecondsSinceEpoch,
        }),
      )
      .catchError((_) => http.Response("", 500));
  // #endregion
}
