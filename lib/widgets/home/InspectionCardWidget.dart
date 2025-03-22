import 'package:flutter/material.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/screens/MapsScreen.dart';
import 'package:intl/intl.dart';

class InspectionCard extends StatelessWidget {
  final Inspection inspection;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onSync;

  const InspectionCard({
    super.key,
    required this.inspection,
    required this.onTap,
    required this.onDelete,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final formateadorFecha = DateFormat('MMM d, yyyy');
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator at the top of the card
            Container(
              height: 8,
              decoration: BoxDecoration(
                color:
                    inspection.status == 'Sincronizada'
                        ? Colors.green.shade400
                        : Colors.amber.shade400,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          inspection.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder:
                                (ctx) => AlertDialog(
                                  title: const Text('Eliminar Inspección'),
                                  content: const Text(
                                    '¿Estás seguro de que quieres eliminar esta inspección?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('CANCELAR'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        onDelete();
                                      },
                                      child: const Text('ELIMINAR'),
                                    ),
                                  ],
                                ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      inspection.status,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: isSmallScreen ? 10 : 12,
                        color:
                            inspection.status == 'Sincronizada'
                                ? Colors.green.shade700
                                : Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    inspection.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: isSmallScreen ? 13 : 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: theme.dividerColor.withAlpha(76), // 0.3 * 255 = ~76
                  ),
                  const SizedBox(height: 16),
                  // Info grid with icons
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                formateadorFecha.format(inspection.date),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: isSmallScreen ? 11 : 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Lat: ${inspection.location[0].toStringAsFixed(2)}, '
                                'Long: ${inspection.location[1].toStringAsFixed(2)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: isSmallScreen ? 11 : 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onSync != null)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.sync, size: 16),
                          label: const Text('Sincronizar'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            foregroundColor: theme.colorScheme.primary,
                            side: BorderSide(color: theme.colorScheme.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: onSync,
                        ),
                      if (onSync != null) const SizedBox(width: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.map, size: 16),
                        label: const Text('Ver mapa'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => MapsScreen(
                                    latitude: inspection.location[0],
                                    longitude: inspection.location[1],
                                    title: inspection.title,
                                  ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
