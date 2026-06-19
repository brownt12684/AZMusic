import 'dart:math' as math;

const double kReaderSpreadMinWidth = 900;

bool isLandscapeSpreadEligible({
  required String format,
  required bool isLandscape,
  required double viewportWidth,
  required double viewportHeight,
  required int pageCount,
}) {
  // Portrait mode (height > width) never spreads — always single page.
  if (viewportWidth <= 0 || viewportHeight <= 0) return false;
  if (viewportHeight > viewportWidth) return false;
  return format.toLowerCase() == 'pdf' &&
      isLandscape &&
      viewportWidth >= kReaderSpreadMinWidth &&
      pageCount > 1;
}

int spreadStartForPage(int pageNumber) {
  final safePage = math.max(1, pageNumber);
  return safePage.isEven ? safePage - 1 : safePage;
}

int spreadEndForPage(int pageNumber, int pageCount) {
  return math.min(pageCount, spreadStartForPage(pageNumber) + 1);
}

int spreadIndexForPage(int pageNumber) {
  return (spreadStartForPage(pageNumber) - 1) ~/ 2;
}

int pageForSpreadIndex(int spreadIndex) {
  return (spreadIndex * 2) + 1;
}

int spreadCountForPages(int pageCount) {
  return (math.max(1, pageCount) + 1) ~/ 2;
}

int previousReaderTarget({
  required int currentPage,
  required bool spreadMode,
}) {
  if (!spreadMode) {
    return math.max(1, currentPage - 1);
  }
  return math.max(1, spreadStartForPage(currentPage) - 2);
}

int nextReaderTarget({
  required int currentPage,
  required int pageCount,
  required bool spreadMode,
}) {
  if (!spreadMode) {
    return math.min(pageCount, currentPage + 1);
  }
  return math.min(pageCount, spreadStartForPage(currentPage) + 2);
}

String readerPagePositionLabel({
  required int currentPage,
  required int pageCount,
  required bool spreadMode,
}) {
  if (!spreadMode) {
    return '$currentPage of $pageCount';
  }

  final startPage = spreadStartForPage(currentPage);
  final endPage = spreadEndForPage(currentPage, pageCount);
  if (startPage == endPage) {
    return '$startPage of $pageCount';
  }
  return '$startPage-$endPage of $pageCount';
}
