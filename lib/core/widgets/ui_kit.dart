import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared building blocks for the hospital-app look: section titles,
/// category-style service icons, avatars and soft cards.

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Round icon + label, like category tiles in shopping / hospital apps.
class ServiceIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const ServiceIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circle with a person's initials.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  const InitialsAvatar(this.name, {super.key, this.size = 44, this.color = AppColors.primary});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty && p[0] != '(').toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Text(
        _initials,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: size * 0.36),
      ),
    );
  }
}

/// White rounded card with a soft shadow (used for hero/content cards).
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color = AppColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0D2B2440), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small stat block used on dashboard headers.
class HeaderStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const HeaderStat({super.key, required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}


/// Mon–Sun strip with circular day chips (today highlighted). An optional
/// status per day draws a small dot underneath (e.g. medicines taken/missed).
class WeekStrip extends StatelessWidget {
  final DateTime today;
  final Color? Function(DateTime day)? dotColor;
  final List<String> weekdayLabels;
  final VoidCallback? onTap;

  const WeekStrip({
    super.key,
    required this.today,
    required this.weekdayLabels,
    this.dotColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(builder: (context) {
                final day = DateTime(monday.year, monday.month, monday.day + i);
                final isToday = day.day == today.day && day.month == today.month;
                final dot = dotColor?.call(day);
                return Column(
                  children: [
                    Text(
                      weekdayLabels[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isToday ? AppColors.textPrimary : AppColors.textSecondary,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday ? AppColors.primary : AppColors.muted,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isToday ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: dot ?? Colors.transparent, shape: BoxShape.circle),
                    ),
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }
}

/// Dashed horizontal divider (invoice-card style).
class DashedDivider extends StatelessWidget {
  final Color color;
  const DashedDivider({super.key, this.color = AppColors.border});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _DashPainter(color)),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset((x + 5).clamp(0, size.width), 0), paint);
      x += 9;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}

/// Circular progress ring with a centred label.
class RingProgress extends StatelessWidget {
  final double value;
  final double size;
  final Color color;
  final Color trackColor;
  final Widget center;

  const RingProgress({
    super.key,
    required this.value,
    required this.center,
    this.size = 108,
    this.color = AppColors.primary,
    this.trackColor = const Color(0x332B2440),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 10,
              color: trackColor,
            ),
          ),
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value.clamp(0, 1),
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: Colors.transparent,
            ),
          ),
          center,
        ],
      ),
    );
  }
}

/// Floating dark pill navigation bar with a separate round action button.
class PillNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<(IconData, IconData, String)> items;
  final Widget action;

  const PillNavBar({
    super.key,
    required this.index,
    required this.onChanged,
    required this.items,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    // Always keep a visible gap under the bar, plus the device's safe area.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, bottomInset + AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 62,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: const [
                    BoxShadow(color: Color(0x332B2440), blurRadius: 20, offset: Offset(0, 8)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Semantics(
                          selected: i == index,
                          button: true,
                          label: items[i].$3,
                          child: InkResponse(
                            onTap: () => onChanged(i),
                            radius: 30,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: i == index ? Colors.white : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                i == index ? items[i].$2 : items[i].$1,
                                color: i == index ? AppColors.primary : Colors.white70,
                              ),
                            ),
                          ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            action,
          ],
        ),
      ),
    );
  }
}

/// Routine checklist row: tick circle on a dotted timeline + card.
class ChecklistTile extends StatelessWidget {
  final String name;
  final String timing;
  final String dose;
  final bool taken;
  final bool isLast;
  final Color tint;
  final Color iconColor;
  final VoidCallback onTap;

  const ChecklistTile({super.key,
    required this.name,
    required this.timing,
    required this.dose,
    required this.taken,
    required this.isLast,
    required this.tint,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline: check circle + dotted connector
          SizedBox(
            width: 34,
            child: Column(
              children: [
                const SizedBox(height: 30),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: taken ? AppColors.accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: taken ? AppColors.accent : const Color(0xFFC9C2BA), width: 1.5),
                  ),
                  child: taken ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1.2, margin: const EdgeInsets.only(top: 4), color: const Color(0xFFDCD5CD)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
              child: SoftCard(
                onTap: onTap,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: Icon(Icons.medication_rounded, color: iconColor),
                    ),
                    const SizedBox(width: AppSpacing.md - 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              decoration: taken ? TextDecoration.lineThrough : null,
                              decorationColor: AppColors.textSecondary,
                            ),
                          ),
                          Text(dose, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 36, color: AppColors.border),
                    SizedBox(
                      width: 78,
                      child: Column(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 18, color: AppColors.textPrimary),
                          const SizedBox(height: 2),
                          Text(timing,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Compact pastel stat tile (number + icon + label).
class StatTile extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  final Color accent;
  final IconData icon;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    required this.accent,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.sm + 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm + 4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1)),
                  const Spacer(),
                  Icon(icon, color: accent, size: 20),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
