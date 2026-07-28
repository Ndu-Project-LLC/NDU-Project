import 'package:flutter/material.dart';

import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';

class PhasePageData {
 const PhasePageData({
 required this.title,
 required this.subtitle,
 required this.description,
 required this.tagline,
 required this.callToActionLabel,
 required this.accentColor,
 this.heroHighlights = const <String>[],
 this.metrics = const <PhaseMetric>[],
 this.focusAreas = const <PhaseFocusArea>[],
 this.timeline = const <PhaseTimelineItem>[],
 this.checklistGroups = const <PhaseChecklistGroup>[],
 this.quickWins = const <String>[],
 this.resourceLinks = const <String>[],
 });

 final String title;
 final String subtitle;
 final String description;
 final String tagline;
 final String callToActionLabel;
 final Color accentColor;
 final List<String> heroHighlights;
 final List<PhaseMetric> metrics;
 final List<PhaseFocusArea> focusAreas;
 final List<PhaseTimelineItem> timeline;
 final List<PhaseChecklistGroup> checklistGroups;
 final List<String> quickWins;
 final List<String> resourceLinks;
}

class PhaseMetric {
 const PhaseMetric({
 required this.label,
 required this.value,
 this.trend,
 this.trendIsPositive = true,
 });

 final String label;
 final String value;
 final String? trend;
 final bool trendIsPositive;
}

class PhaseFocusArea {
 const PhaseFocusArea({
 required this.title,
 required this.caption,
 this.points = const <String>[],
 });

 final String title;
 final String caption;
 final List<String> points;
}

class PhaseTimelineItem {
 const PhaseTimelineItem({
 required this.label,
 required this.description,
 required this.timeframe,
 });

 final String label;
 final String description;
 final String timeframe;
}

class PhaseChecklistGroup {
 const PhaseChecklistGroup({
 required this.title,
 this.items = const <String>[],
 });

 final String title;
 final List<String> items;
}

class PhaseDetailScreen extends StatelessWidget {
 const PhaseDetailScreen({
 super.key,
 required this.data,
 required this.activeSidebarLabel,
 });

 final PhasePageData data;
 final String activeSidebarLabel;

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 20 : 32;
 final double verticalPadding = isMobile ? 24 : 32;

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: InitiationLikeSidebar(activeItemLabel: activeSidebarLabel),
 ),
 Expanded(
 child: Stack(
 children: [
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _HeroHeader(data: data),
 const SizedBox(height: 28),
 _OverviewCard(data: data),
 if (data.metrics.isNotEmpty) ...[
 const SizedBox(height: 28),
 _MetricsCard(metrics: data.metrics, accent: data.accentColor),
 ],
 if (data.focusAreas.isNotEmpty) ...[
 const SizedBox(height: 28),
 _FocusAreasGrid(focusAreas: data.focusAreas),
 ],
 if (data.timeline.isNotEmpty) ...[
 const SizedBox(height: 28),
 _TimelineCard(items: data.timeline, accent: data.accentColor),
 ],
 if (data.checklistGroups.isNotEmpty) ...[
 const SizedBox(height: 28),
 _ChecklistCard(groups: data.checklistGroups),
 ],
 if (data.quickWins.isNotEmpty || data.resourceLinks.isNotEmpty) ...[
 const SizedBox(height: 28),
 _ResourcesStrip(
 quickWins: data.quickWins,
 resources: data.resourceLinks,
 accent: data.accentColor,
 ),
 ],
 const SizedBox(height: 80),
 ],
 ),
 ),
 const KazAiChatBubble(),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _HeroHeader extends StatelessWidget {
 const _HeroHeader({required this.data});

 final PhasePageData data;

 @override
 Widget build(BuildContext context) {
 final Color accent = data.accentColor;
 return Container(
 padding: const EdgeInsets.all(30),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(color: Color(0x08000000), blurRadius: 20, offset: Offset(0, 16)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
 decoration: BoxDecoration(
 color: accent.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 data.subtitle.toUpperCase(),
 style: TextStyle(
 color: accent,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.5,
 ),
 ),
 ),
 const Spacer(),
 ElevatedButton.icon(
 onPressed: () {},
 icon: const Icon(Icons.bolt, size: 18, color: Color(0xFF111827)),
 label: Text(
 data.callToActionLabel,
 style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827)),
 ),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFC812),
 foregroundColor: const Color(0xFF111827),
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 elevation: 0,
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 Text(
 data.title,
 style: const TextStyle(
 color: Color(0xFF111827),
 fontSize: 28,
 fontWeight: FontWeight.w800,
 height: 1.2,
 ),
 ),
 const SizedBox(height: 12),
 Text(
 data.tagline,
 style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14, height: 1.6, fontWeight: FontWeight.w500),
 ),
 if (data.heroHighlights.isNotEmpty) ...[
 const SizedBox(height: 20),
 Wrap(
 spacing: 12,
 runSpacing: 10,
 children: data.heroHighlights
 .map((highlight) => _GlowPill(label: highlight, accent: accent))
 .toList(),
 ),
 ],
 ],
 ),
 );
 }
}

class _OverviewCard extends StatelessWidget {
 const _OverviewCard({required this.data});

 final PhasePageData data;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(30),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Overview',
 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
 ),
 const SizedBox(height: 12),
 Text(
 data.description,
 style: const TextStyle(fontSize: 14, height: 1.7, color: Color(0xFF4B5563), fontWeight: FontWeight.w500),
 ),
 ],
 ),
 );
 }
}

class _MetricsCard extends StatelessWidget {
 const _MetricsCard({required this.metrics, required this.accent});

 final List<PhaseMetric> metrics;
 final Color accent;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(26),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final bool useTwoColumns = constraints.maxWidth > 760;
 final int crossAxisCount = useTwoColumns ? 3 : 1;
 return Wrap(
 spacing: 20,
 runSpacing: 20,
 children: metrics.map((metric) {
 return SizedBox(
 width: useTwoColumns ? (constraints.maxWidth - 40) / crossAxisCount : double.infinity,
 child: _MetricTile(metric: metric, accent: accent),
 );
 }).toList(),
 );
 },
 ),
 );
 }
}

class _MetricTile extends StatelessWidget {
 const _MetricTile({required this.metric, required this.accent});

 final PhaseMetric metric;
 final Color accent;

 @override
 Widget build(BuildContext context) {
 final Color badgeColor = accent.withOpacity(0.12);
 final Color trendColor = metric.trendIsPositive ? const Color(0xFF047857) : const Color(0xFFB91C1C);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(999)),
 child: Text(
 metric.label,
 style: TextStyle(
 color: accent,
 fontSize: 12,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 const SizedBox(height: 14),
 Text(
 metric.value,
 style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
 ),
 if (metric.trend != null) ...[
 const SizedBox(height: 6),
 Row(
 children: [
 Icon(
 metric.trendIsPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
 size: 18,
 color: trendColor,
 ),
 const SizedBox(width: 4),
 Text(
 metric.trend!,
 style: TextStyle(color: trendColor, fontSize: 13, fontWeight: FontWeight.w600),
 ),
 ],
 ),
 ],
 ],
 ),
 );
 }
}

class _FocusAreasGrid extends StatelessWidget {
 const _FocusAreasGrid({required this.focusAreas});

 final List<PhaseFocusArea> focusAreas;

 @override
 Widget build(BuildContext context) {
 return LayoutBuilder(
 builder: (context, constraints) {
 final bool twoColumns = constraints.maxWidth > 900;
 final double tileWidth = twoColumns ? (constraints.maxWidth - 26) / 2 : constraints.maxWidth;
 return Wrap(
 spacing: 26,
 runSpacing: 26,
 children: focusAreas.map((area) {
 return SizedBox(
 width: tileWidth,
 child: Container(
 padding: const EdgeInsets.all(26),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(color: Color(0x08000000), blurRadius: 18, offset: Offset(0, 12)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 area.title,
 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
 ),
 const SizedBox(height: 12),
 Text(
 area.caption,
 style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.6),
 ),
 if (area.points.isNotEmpty) ...[
 const SizedBox(height: 16),
 ...area.points.map((point) => Padding(
 padding: const EdgeInsets.symmetric(vertical: 6),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Padding(
 padding: EdgeInsets.only(top: 6),
 child: Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981)),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 point,
 style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.6),
 ),
 ),
 ],
 ),
 )),
 ],
 ],
 ),
 ),
 );
 }).toList(),
 );
 },
 );
 }
}

class _TimelineCard extends StatelessWidget {
 const _TimelineCard({required this.items, required this.accent});

 final List<PhaseTimelineItem> items;
 final Color accent;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(28),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Momentum Timeline',
 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
 ),
 const SizedBox(height: 18),
 ...items.asMap().entries.map((entry) {
 final index = entry.key;
 final item = entry.value;
 final bool isLast = index == items.length - 1;
 return _TimelineTile(item: item, accent: accent, showConnector: !isLast);
 }),
 ],
 ),
 );
 }
}

class _TimelineTile extends StatelessWidget {
 const _TimelineTile({required this.item, required this.accent, required this.showConnector});

 final PhaseTimelineItem item;
 final Color accent;
 final bool showConnector;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 18),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Column(
 children: [
 Container(
 width: 16,
 height: 16,
 decoration: BoxDecoration(
 color: accent,
 shape: BoxShape.circle,
 boxShadow: [
 BoxShadow(color: accent.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 6)),
 ],
 ),
 ),
 if (showConnector)
 Container(
 width: 2,
 height: 62,
 margin: const EdgeInsets.symmetric(vertical: 4),
 color: const Color(0xFFE5E7EB),
 ),
 ],
 ),
 const SizedBox(width: 18),
 Expanded(
 child: Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 item.timeframe,
 style: TextStyle(
 color: accent,
 fontSize: 12,
 fontWeight: FontWeight.w700,
 ),
 ),
 const SizedBox(height: 6),
 Text(
 item.label,
 style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
 ),
 const SizedBox(height: 8),
 Text(
 item.description,
 style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.6),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _ChecklistCard extends StatelessWidget {
 const _ChecklistCard({required this.groups});

 final List<PhaseChecklistGroup> groups;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(30),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Execution Checklist',
 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
 ),
 const SizedBox(height: 20),
 ...groups.map((group) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 group.title,
 style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
 ),
 const SizedBox(height: 12),
 ...group.items.map((item) => Padding(
 padding: const EdgeInsets.symmetric(vertical: 6),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Icon(Icons.check_box_outlined, size: 18, color: Color(0xFF6B7280)),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 item,
 style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.6),
 ),
 ),
 ],
 ),
 )),
 ],
 ),
 );
 }),
 ],
 ),
 );
 }
}

class _ResourcesStrip extends StatelessWidget {
 const _ResourcesStrip({required this.quickWins, required this.resources, required this.accent});

 final List<String> quickWins;
 final List<String> resources;
 final Color accent;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (quickWins.isNotEmpty) ...[
 const Text(
 'Quick Wins',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
 ),
 const SizedBox(height: 12),
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: quickWins.map((item) => _GlowPill(label: item, accent: accent)).toList(),
 ),
 if (resources.isNotEmpty) const SizedBox(height: 26),
 ],
 if (resources.isNotEmpty) ...[
 const Text(
 'Resource Library',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
 ),
 const SizedBox(height: 12),
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: resources
 .map(
 (item) => Chip(
 avatar: const Icon(Icons.link, size: 16, color: Color(0xFF1F2937)),
 label: Text(item),
 backgroundColor: const Color(0xFFF3F4F6),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
 ),
 )
 .toList(),
 ),
 ],
 ],
 ),
 );
 }
}

class _GlowPill extends StatelessWidget {
 const _GlowPill({required this.label, required this.accent});

 final String label;
 final Color accent;

 @override
 Widget build(BuildContext context) {
 final Color background = accent.withOpacity(0.12);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
 decoration: BoxDecoration(
 color: background,
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: accent.withOpacity(0.45)),
 ),
 child: Text(
 label,
 style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
 ),
 );
 }
}