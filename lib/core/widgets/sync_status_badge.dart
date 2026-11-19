import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../services/sync_service.dart';
import '../database/local_db.dart';
import '../../app_state.dart';

class SyncStatusBadge extends StatelessWidget {
  final bool compact;

  const SyncStatusBadge({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<SyncService>();
    final isOnline = syncService.isOnline;
    final isSimulated = syncService.isSimulatedOffline;
    final isSyncing = syncService.isSyncing;
    final pendingCount = syncService.pendingCount;

    Color badgeColor;
    Color textColor;
    IconData icon;
    String label;

    if (isSyncing) {
      badgeColor = AppColors.infoContainer;
      textColor = AppColors.primary;
      icon = Icons.sync;
      label = 'Syncing...';
    } else if (!isOnline) {
      badgeColor = isSimulated ? AppColors.warningContainer : AppColors.dangerContainer;
      textColor = isSimulated ? AppColors.warning : AppColors.danger;
      icon = Icons.cloud_off_rounded;
      label = isSimulated ? 'Offline (Demo)' : 'Offline';
      if (pendingCount > 0) {
        label = '$label • $pendingCount';
      }
    } else if (pendingCount > 0) {
      badgeColor = AppColors.warningContainer;
      textColor = AppColors.warning;
      icon = Icons.cloud_upload_outlined;
      label = '$pendingCount Pending';
    } else {
      badgeColor = AppColors.successContainer;
      textColor = AppColors.success;
      icon = Icons.cloud_done_rounded;
      label = 'Synced';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showSyncSheet(context, syncService),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: textColor.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSyncing)
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                else
                  Icon(icon, size: 14, color: textColor),
                if (!compact) ...[
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSyncSheet(BuildContext context, SyncService syncService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SyncDetailsSheet(syncService: syncService),
    );
  }
}

class _SyncDetailsSheet extends StatefulWidget {
  final SyncService syncService;

  const _SyncDetailsSheet({required this.syncService});

  @override
  State<_SyncDetailsSheet> createState() => _SyncDetailsSheetState();
}

class _SyncDetailsSheetState extends State<_SyncDetailsSheet> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final syncService = widget.syncService;
    final state = AppState.instance;
    final isOnline = syncService.isOnline;
    final isSimulated = syncService.isSimulatedOffline;
    final pendingCount = syncService.pendingCount;
    final queueItems = LocalDb.getPendingSyncItems();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isOnline ? AppColors.successContainer : AppColors.warningContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: isOnline ? AppColors.success : AppColors.warning,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.translate('Sync & Offline Management', 'सिंक और ऑफलाइन प्रबंधन', 'सिंक आणि ऑफलाइन व्यवस्थापन'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isOnline
                          ? state.translate('Connected to Cloud Database', 'क्लाउड डेटाबेस से कनेक्टेड', 'क्लाउड डेटाबेसशी जोडलेले')
                          : (isSimulated
                              ? state.translate('Simulated Airplane Mode active', 'सिम्युलेटेड एयरप्लेन मोड सक्रिय', 'सिम्युलेटेड एअरप्लेन मोड सुरू')
                              : state.translate('No network detected', 'नेटवर्क उपलब्ध नाही', 'नेटवर्क सापडले नाही')),
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),

          // ── Offline Mode Switch (demo builds only) ───────────────────────
          if (AppConfig.demoMode) Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.airplanemode_active, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.translate('Simulate Offline / Airplane Mode', 'ऑफलाइन / एयरप्लेन मोड सिम्युलेट करें', 'ऑफलाइन / एअरप्लेन मोड सिम्युलेट करा'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        state.translate('Forces outbox queuing for competition demonstration', 'प्रतियोगिता प्रदर्शन के लिए आउटबॉक्स कतार का परीक्षण करें', 'स्पर्धा प्रात्यक्षिकासाठी आउटबॉक्स रांग तपासा'),
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isSimulated,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) {
                    syncService.setSimulatedOffline(val);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Outbox Status ────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.translate('Pending Outbox Mutations', 'लंबित आउटबॉक्स म्यूटेशन', 'प्रलंबित आउटबॉक्स नोंदी'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: pendingCount > 0 ? AppColors.warningContainer : AppColors.successContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pendingCount ${state.translate('Items', 'आइटम', 'नोंदी')}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: pendingCount > 0 ? AppColors.warning : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (syncService.deadLetterCount > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.translate(
                        '${syncService.deadLetterCount} records were rejected by the server and need review by your PHC.',
                        '${syncService.deadLetterCount} रिकॉर्ड सर्वर ने अस्वीकार किए; PHC द्वारा समीक्षा आवश्यक।',
                        '${syncService.deadLetterCount} नोंदी सर्व्हरने नाकारल्या; PHC कडून तपासणी आवश्यक.',
                      ),
                      style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (queueItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.successContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.translate('All local records are synchronized with server.', 'सभी स्थानीय रिकॉर्ड सर्वर के साथ समन्वयित हैं।', 'सर्व स्थानिक नोंदी सर्व्हरशी सिंक केलेल्या आहेत.'),
                      style: const TextStyle(fontSize: 12, color: AppColors.success),
                    ),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: queueItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, idx) {
                  final item = queueItems[idx];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.outbox, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${item['action']?.toString().toUpperCase()}: ${item['table']}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          item['enqueued_at'] != null
                              ? item['enqueued_at'].toString().substring(11, 16)
                              : '',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 20),

          // ── Sync Action Button ───────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(
                _isLoading
                    ? state.translate('Syncing...', 'सिंक हो रहा है...', 'सिंक होत आहे...')
                    : state.translate('Sync Now (Drain Outbox)', 'अभी सिंक करें', 'आता सिंक करा'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              onPressed: _isLoading || (!isOnline && !isSimulated && pendingCount == 0)
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);

                      setState(() => _isLoading = true);
                      if (isSimulated) {
                        syncService.setSimulatedOffline(false);
                      }
                      final result = await syncService.syncNow();
                      if (!mounted) return;

                      setState(() => _isLoading = false);
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(result.message),
                          backgroundColor: result.success ? AppColors.success : AppColors.danger,
                        ),
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }
}
