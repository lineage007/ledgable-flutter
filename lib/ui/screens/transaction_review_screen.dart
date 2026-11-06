import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models/transaction.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../data/transactions_repository.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../shell.dart';
import '../widgets/category_picker.dart';
import '../widgets/common.dart';

/// The queue of uncategorised bank transactions.
///
/// The highest-frequency, lowest-friction task there is, so it is built for one
/// thumb: swipe right to accept the last category used for that merchant, swipe
/// left to pick one, tap to see the detail. Every action is reversible, and the
/// undo is offered in the snackbar rather than hidden in a menu, because the
/// whole point of a fast gesture is that it will sometimes be the wrong one.
class TransactionReviewScreen extends ConsumerStatefulWidget {
  const TransactionReviewScreen({super.key});

  @override
  ConsumerState<TransactionReviewScreen> createState() => _TransactionReviewScreenState();
}

class _TransactionReviewScreenState extends ConsumerState<TransactionReviewScreen> {
  final _scrollController = ScrollController();

  List<TransactionRecord> _queue = [];
  List<CategoryOption> _categories = [];
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  int _total = 0;
  bool _hasMore = false;

  /// Ids currently being sent to the server, so a double-tap cannot categorise
  /// the same transaction twice.
  final _inFlight = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  TransactionsRepository get _repository => ref.read(transactionsRepositoryProvider);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repository.list(filter: TransactionFilter.needsReview);
      // The category list comes from codes the workspace has actually used;
      // there is no /categories endpoint. A failure here must not block the
      // queue — the picker falls back to a typed code.
      final categories = await _loadCategories();
      if (!mounted) return;
      setState(() {
        // List.of, not the repository's list: the queue is mutated in place when
        // a swipe removes a row or a failure puts one back, and the repository
        // hands back a fixed-length list.
        _queue = List.of(page.items);
        _total = page.page.total;
        _hasMore = page.page.hasMore;
        _categories = List.of(categories);
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<List<CategoryOption>> _loadCategories() async {
    try {
      return await _repository.usedCategories();
    } on Object {
      return const [];
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final page = await _repository.list(
        filter: TransactionFilter.needsReview,
        offset: _queue.length,
      );
      if (!mounted) return;
      setState(() {
        // Dedupe by id: categorising removes rows from the server's queue, so a
        // later page can overlap with what is already on screen.
        final seen = _queue.map((transaction) => transaction.id).toSet();
        _queue = [..._queue, ...page.items.where((item) => !seen.contains(item.id))];
        _hasMore = page.page.hasMore;
      });
    } on Object catch (error) {
      if (!mounted) return;
      showErrorToast(context, error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _categorise(TransactionRecord transaction, String categoryCode) async {
    if (_inFlight.contains(transaction.id)) return;
    setState(() => _inFlight.add(transaction.id));

    // Remove it optimistically: the queue is a working surface and leaving a row
    // in place while the request flies makes the gesture feel unacknowledged.
    final index = _queue.indexWhere((item) => item.id == transaction.id);
    setState(() {
      if (index >= 0) _queue.removeAt(index);
      if (_total > 0) _total--;
    });

    try {
      final result = await _repository.categorise(
        transactionId: transaction.id,
        categoryCode: categoryCode,
      );
      if (!mounted) return;

      // Fold the newly used code into the picker so the next transaction can
      // accept it without a round trip.
      _rememberCategory(categoryCode);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${transaction.title} → ${CategoryOption(code: categoryCode, usageCount: 0).label}',
            ),
            action: SnackBarAction(label: 'Undo', onPressed: () => _undo(transaction, result)),
          ),
        );
    } on Object catch (error) {
      if (!mounted) return;
      // Put it back. A failed categorisation that silently removed the row would
      // lose work.
      setState(() {
        final at = index < 0 || index > _queue.length ? _queue.length : index;
        _queue.insert(at, transaction);
        _total++;
      });
      showErrorToast(context, error);
    } finally {
      if (mounted) setState(() => _inFlight.remove(transaction.id));
    }
  }

  /// Undo by categorising again — the same operation in reverse, which is what
  /// makes it safe. When there was no prior category the row simply returns to
  /// the queue, because the API has no "uncategorise" call.
  Future<void> _undo(TransactionRecord transaction, CategorisationResult result) async {
    final previous = result.previousCategoryCode;
    if (previous == null) {
      setState(() {
        _queue.insert(0, transaction);
        _total++;
      });
      if (!mounted) return;
      showSuccessToast(
        context,
        'Back in the queue. It is still categorised as '
        '${CategoryOption(code: result.categoryCode, usageCount: 0).label} until you change it.',
      );
      return;
    }

    try {
      await _repository.categorise(transactionId: transaction.id, categoryCode: previous);
      if (!mounted) return;
      showSuccessToast(
        context,
        'Put back to ${CategoryOption(code: previous, usageCount: 0).label}.',
      );
    } on Object catch (error) {
      if (!mounted) return;
      showErrorToast(context, error);
    }
  }

  void _rememberCategory(String code) {
    final existing = _categories.indexWhere((option) => option.code == code);
    setState(() {
      if (existing >= 0) {
        _categories[existing] = CategoryOption(
          code: code,
          usageCount: _categories[existing].usageCount + 1,
        );
      } else {
        _categories = [..._categories, CategoryOption(code: code, usageCount: 1)];
      }
      _categories.sort((a, b) {
        final byUsage = b.usageCount.compareTo(a.usageCount);
        return byUsage != 0 ? byUsage : a.code.compareTo(b.code);
      });
    });
  }

  Future<void> _pickCategoryFor(TransactionRecord transaction) async {
    final chosen = await showCategoryPicker(
      context,
      options: _categories,
      transactionTitle: transaction.title,
    );
    if (chosen == null) return;
    await _categorise(transaction, chosen);
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = ref.watch(canWriteProvider);

    return Scaffold(
      appBar: WorkspaceAppBar(
        title: 'Review',
        actions: [
          if (_total > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: StatusPill(label: '$_total to sort', tone: PillTone.accent),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(canWrite)),
    );
  }

  Widget _buildBody(bool canWrite) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: const [
          _QueueSkeleton(),
          SizedBox(height: 12),
          _QueueSkeleton(),
          SizedBox(height: 12),
          _QueueSkeleton(),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.only(top: 80),
        children: [ErrorView(error: _error!, onRetry: _load)],
      );
    }

    if (_queue.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 60),
        children: [
          SizedBox(
            height: 380,
            child: EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'Nothing to review',
              message:
                  'Every transaction Ledgable can see has a category. '
                  'New ones will show up here as they come through your bank feed.',
            ),
          ),
        ],
      );
    }

    if (!canWrite) {
      // The role map says this person may read but not write, so the API would
      // refuse a categorisation. Show the queue without the gestures rather than
      // offering a tap that 403s.
      return ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: _queue.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Your role on this workspace is read-only, so these are shown for '
                'information. Ask an owner or admin to categorise them.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }
          return _TransactionCard(transaction: _queue[index - 1]);
        },
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: _queue.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= _queue.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final transaction = _queue[index];
        final suggestion = _suggestionFor(transaction);

        return Dismissible(
          key: ValueKey(transaction.id),
          // Right swipe accepts the suggestion, left swipe opens the picker.
          // Only enable the accept direction when there is something to accept.
          direction: suggestion == null ? DismissDirection.endToStart : DismissDirection.horizontal,
          background: _SwipeBackground(
            alignment: Alignment.centerLeft,
            icon: Icons.check_rounded,
            label: suggestion == null ? '' : 'File as ${suggestion.label}',
            colour: context.c.positive,
          ),
          secondaryBackground: _SwipeBackground(
            alignment: Alignment.centerRight,
            icon: Icons.sell_outlined,
            label: 'Choose a category',
            colour: context.c.accent,
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              if (suggestion == null) return false;
              await _categorise(transaction, suggestion.code);
              // _categorise already removed the row, so the Dismissible must not
              // remove it a second time.
              return false;
            }
            await _pickCategoryFor(transaction);
            return false;
          },
          child: _TransactionCard(
            transaction: transaction,
            suggestion: suggestion,
            busy: _inFlight.contains(transaction.id),
            onTap: () => _pickCategoryFor(transaction),
          ),
        );
      },
    );
  }

  /// What a right swipe would file this as.
  ///
  /// The most-used category in the workspace. It is a genuine suggestion rather
  /// than a prediction: the API exposes no per-merchant history to the phone, so
  /// claiming "we recognised this merchant" would be a claim the client cannot
  /// support. The label always names the category, so an accepted swipe is never
  /// a surprise.
  CategoryOption? _suggestionFor(TransactionRecord transaction) =>
      _categories.isEmpty ? null : _categories.first;
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    this.suggestion,
    this.busy = false,
    this.onTap,
  });

  final TransactionRecord transaction;
  final CategoryOption? suggestion;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final isIncome = transaction.isIncome;

    return LedgerCard(
      onTap: busy ? null : onTap,
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
                      transaction.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Dates.relative(transaction.effectiveDate),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (busy)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  Money.format(transaction.absAmount),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isIncome ? colors.positive : colors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          if (transaction.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              transaction.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (onTap != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (suggestion != null) ...[
                  Icon(Icons.swipe_right_rounded, size: 14, color: colors.textTertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Swipe right for ${suggestion!.label}, left to choose',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ] else ...[
                  Icon(Icons.swipe_left_rounded, size: 14, color: colors.textTertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Swipe left or tap to choose a category',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.colour,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colour, size: 20),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colour, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _QueueSkeleton extends StatelessWidget {
  const _QueueSkeleton();

  @override
  Widget build(BuildContext context) {
    return const LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SkeletonBlock(width: 140, height: 16)),
              SizedBox(width: 12),
              SkeletonBlock(width: 70, height: 18),
            ],
          ),
          SizedBox(height: 12),
          SkeletonBlock(width: 200, height: 10),
        ],
      ),
    );
  }
}
