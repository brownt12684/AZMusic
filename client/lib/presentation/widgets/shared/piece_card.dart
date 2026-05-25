import 'package:flutter/material.dart';

import '../../../app/app_keys.dart';
import '../../../domain/entities/piece.dart';

class PieceCard extends StatelessWidget {
  final Piece piece;
  final VoidCallback onTap;

  const PieceCard({
    super.key,
    required this.piece,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final difficultyColor = _difficultyColor(piece.difficulty, theme);

    return Card(
      key: AppKeys.pieceCard(piece.id),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          piece.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (piece.composer != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            piece.composer!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (piece.difficulty != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: difficultyColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        piece.difficulty!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: difficultyColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              if (piece.genre != null || piece.keySignature != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (piece.keySignature != null)
                      _chip(theme, piece.keySignature!),
                    if (piece.genre != null) _chip(theme, piece.genre!),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Color _difficultyColor(String? difficulty, ThemeData theme) {
    if (difficulty == null) return theme.colorScheme.primary;
    final lower = difficulty.toLowerCase();
    if (lower.contains('begin') || lower.contains('elem')) return Colors.green;
    if (lower.contains('inter')) return Colors.orange;
    if (lower.contains('adv') || lower.contains('prof')) return Colors.red;
    return theme.colorScheme.primary;
  }
}
