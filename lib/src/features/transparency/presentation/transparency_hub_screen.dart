import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";
import "package:url_launcher/url_launcher.dart";
import "package:youtube_player_iframe/youtube_player_iframe.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../investment/presentation/widgets/allocation_pie_chart_widget.dart";
import "../data/founder_performance_data.dart";
import "../transparency_config.dart";
import "widgets/founder_performance_chart.dart";

final _pctFmt = NumberFormat.decimalPatternDigits(decimalDigits: 2);
final _moneyCompact = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);

class TransparencyHubScreen extends StatelessWidget {
  const TransparencyHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: AppScaffold(
        title: context.tr("transparency_hub_title"),
        body: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: context.tr("transparency_tab_founder")),
                Tab(text: context.tr("transparency_tab_strategy")),
                Tab(text: context.tr("transparency_tab_performance")),
                Tab(text: context.tr("transparency_tab_legal")),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: const [
                  _FounderTab(),
                  _StrategyTab(),
                  _PerformanceTab(),
                  _LegalReadonlyTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FounderTab extends StatefulWidget {
  const _FounderTab();

  @override
  State<_FounderTab> createState() => _FounderTabState();
}

class _FounderTabState extends State<_FounderTab>
    with AutomaticKeepAliveClientMixin {
  late final YoutubePlayerController _yt;

  @override
  void initState() {
    super.initState();
    _yt = YoutubePlayerController.fromVideoId(
      videoId: kFounderIntroYoutubeVideoId,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _openEmail() async {
    final uri = Uri.parse(
      "mailto:$kFounderContactEmail?subject=${Uri.encodeComponent("Wakalat Invest — inquiry")}",
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr("founder_name_full"),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr("founder_title_role"),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: YoutubePlayer(
              controller: _yt,
              gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr("founder_contact_hint"),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          _Paragraph(text: context.tr("founder_bio_p1")),
          _Paragraph(text: context.tr("founder_bio_p2")),
          _Paragraph(text: context.tr("founder_mission")),
          _Paragraph(text: context.tr("founder_vision")),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openEmail,
            icon: const Icon(Icons.mail_outline_rounded),
            label: Text(context.tr("founder_contact_cta")),
          ),
        ],
      ),
    );
  }
}

class _StrategyTab extends StatelessWidget {
  const _StrategyTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Paragraph(text: context.tr("strategy_intro")),
          const SizedBox(height: 12),
          _Paragraph(text: context.tr("strategy_diversification")),
          const SizedBox(height: 12),
          _Paragraph(text: context.tr("strategy_risk")),
          const SizedBox(height: 16),
          Text(
            context.tr("strategy_alloc_note"),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: const AllocationPieChartWidget(),
          ),
        ],
      ),
    );
  }
}

class _PerformanceTab extends StatelessWidget {
  const _PerformanceTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final retPct = founderIllustrativeTotalReturnPct();
    final net = founderIllustrativeNetGainPkr();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr("performance_title"),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _Paragraph(text: context.tr("performance_founder_note")),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: scheme.onSurface, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr("transparency_past_performance_warning"),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: context.tr("performance_total_return"),
                  value: "${_pctFmt.format(retPct)}%",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: context.tr("performance_net_gain"),
                  value: _moneyCompact.format(net),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.tr("performance_illustrative_monthly"),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          FounderPerformanceChart(points: kFounderPerformanceSeries),
          const SizedBox(height: 12),
          Text(
            context.tr("performance_disclaimer"),
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalReadonlyTab extends StatelessWidget {
  const _LegalReadonlyTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = 1; i <= 7; i++) ...[
          _Paragraph(text: context.tr("legal_para_$i")),
          const SizedBox(height: 12),
        ],
        Text(
          context.tr("performance_disclaimer"),
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.push("/legal"),
          child: Text(context.tr("view_legal_consent")),
        ),
      ],
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
    );
  }
}
