import "package:flutter/material.dart";

import "../branding/brand_assets.dart";
import "../theme/app_colors.dart";

class FinanceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FinanceAppBar({
    super.key,
    required this.title,
    this.onLogin,
    this.onGetStarted,
  });

  final String title;
  final VoidCallback? onLogin;
  final VoidCallback? onGetStarted;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Image.asset(
            BrandAssets.logoPng,
            height: 32,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(onPressed: onLogin, child: const Text("Login")),
        const SizedBox(width: 10),
        FilledButton(onPressed: onGetStarted, child: const Text("Get Started")),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(onPressed: onPressed, child: Text(label));
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AppInputField extends StatelessWidget {
  const AppInputField({
    super.key,
    required this.hint,
    this.controller,
  });

  final String hint;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(hintText: hint),
    );
  }
}

class HeroSplitSection extends StatelessWidget {
  const HeroSplitSection({
    super.key,
    required this.left,
    required this.right,
  });

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final mobile = constraints.maxWidth < 900;
        if (mobile) {
          return Column(
            children: [
              left,
              const SizedBox(height: 16),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 20),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}
