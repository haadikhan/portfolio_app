import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../providers/auth_providers.dart";
import "../models/admin_investor_models.dart";
import "../providers/admin_providers.dart";
import "crm_models.dart";
import "crm_service.dart";

final crmServiceProvider = Provider<CrmService>((ref) {
  return CrmService(
    ref.read(firebaseFirestoreProvider),
    ref.read(adminInvestorServiceProvider),
  );
});

/// CRM staff directory (admin reads `users` where `role == crm`).
final crmStaffMembersProvider = StreamProvider<List<AdminInvestorSummary>>((ref) {
  return ref
      .read(firebaseFirestoreProvider)
      .collection("users")
      .where("role", isEqualTo: "crm")
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => AdminInvestorSummary.fromFirestore(d.id, d.data()))
            .toList(),
      );
});

final crmInvestorSearchQueryProvider = StateProvider<String>((ref) => "");

final crmFilteredInvestorsProvider =
    Provider<AsyncValue<List<AdminInvestorSummary>>>((ref) {
  final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  final role = ref.watch(adminRoleProvider).valueOrNull ?? "";
  final r = role.toLowerCase();
  final isAdmin = r == "admin";
  final key = (isAdmin: isAdmin, crmUid: uid);
  final async = ref.watch(crmAssignedInvestorsProvider(key));
  final q = ref.watch(crmInvestorSearchQueryProvider).trim().toLowerCase();
  return async.whenData((investors) {
    if (q.isEmpty) return investors;
    return investors.where((u) {
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.phone.toLowerCase().contains(q);
    }).toList();
  });
});

final crmAssignedInvestorsProvider =
    FutureProvider.family<List<AdminInvestorSummary>, ({bool isAdmin, String? crmUid})>(
  (ref, key) async {
    final svc = ref.read(crmServiceProvider);
    return svc.fetchInvestorsForCrm(
      crmUid: key.crmUid ?? "",
      isAdmin: key.isAdmin,
    );
  },
);

final crmAssignmentProvider =
    FutureProvider.family<CrmAssignment?, String>((ref, investorUid) {
  return ref.read(crmServiceProvider).getAssignment(investorUid);
});

final crmNotesStreamProvider =
    StreamProvider.family<List<CrmNote>, String>((ref, investorUid) {
  return ref.read(crmServiceProvider).watchNotes(investorUid);
});

final crmFollowupsStreamProvider =
    StreamProvider.family<List<CrmFollowup>, String>((ref, investorUid) {
  return ref.read(crmServiceProvider).watchFollowups(investorUid);
});

final crmCommunicationsStreamProvider =
    StreamProvider.family<List<CrmCommunication>, String>((ref, investorUid) {
  return ref.read(crmServiceProvider).watchCommunications(investorUid);
});

final crmPendingFollowupsCountProvider = FutureProvider.family<int, String>(
  (ref, crmUid) {
    return ref.read(crmServiceProvider).countPendingFollowupsForCrm(crmUid);
  },
);
