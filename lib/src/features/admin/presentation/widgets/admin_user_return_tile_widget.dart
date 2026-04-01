import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../../core/theme/app_colors.dart";

final _money = NumberFormat.currency(symbol: "PKR ", decimalDigits: 2);

class AdminUserReturnTile extends StatelessWidget {
  const AdminUserReturnTile({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.currentValue,
    required this.controller,
    required this.onApply,
    required this.isProcessing,
  });

  final String userName;
  final String userEmail;
  final double currentValue;
  final TextEditingController controller;
  final VoidCallback onApply;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.secondary,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : "?",
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName.isNotEmpty ? userName : "Unknown",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.heading,
                      ),
                    ),
                    Text(
                      userEmail,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.bodyMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "Portfolio value",
                    style:
                        TextStyle(fontSize: 10, color: AppColors.bodyMuted),
                  ),
                  Text(
                    currentValue > 0 ? _money.format(currentValue) : "—",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: "Manual profit (PKR)",
                    prefixIcon: Icon(Icons.attach_money_rounded, size: 18),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 42,
                child: FilledButton(
                  onPressed: isProcessing ? null : onApply,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Apply"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
