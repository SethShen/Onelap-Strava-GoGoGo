class SyncSummary {
  final int fetched;
  final int deduped;
  final int success;
  final int failed;
  final String? abortedReason;
  final List<String> failureReasons;

  const SyncSummary({
    required this.fetched,
    required this.deduped,
    required this.success,
    required this.failed,
    this.abortedReason,
    this.failureReasons = const [],
  });
}
