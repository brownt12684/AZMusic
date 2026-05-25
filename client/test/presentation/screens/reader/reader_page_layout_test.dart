import 'package:azmusic/presentation/screens/reader/reader_page_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('landscape spread rules keep PDFs only and require wide landscape', () {
    expect(
      isLandscapeSpreadEligible(
        format: 'pdf',
        isLandscape: true,
        viewportWidth: 1200,
        pageCount: 6,
      ),
      isTrue,
    );
    expect(
      isLandscapeSpreadEligible(
        format: 'image',
        isLandscape: true,
        viewportWidth: 1200,
        pageCount: 6,
      ),
      isFalse,
    );
    expect(
      isLandscapeSpreadEligible(
        format: 'pdf',
        isLandscape: false,
        viewportWidth: 1200,
        pageCount: 6,
      ),
      isFalse,
    );
  });

  test('spread labels use page ranges and handle odd page counts', () {
    expect(
      readerPagePositionLabel(
        currentPage: 1,
        pageCount: 6,
        spreadMode: true,
      ),
      '1-2 of 6',
    );
    expect(
      readerPagePositionLabel(
        currentPage: 6,
        pageCount: 7,
        spreadMode: true,
      ),
      '5-6 of 7',
    );
    expect(
      readerPagePositionLabel(
        currentPage: 7,
        pageCount: 7,
        spreadMode: true,
      ),
      '7 of 7',
    );
  });

  test(
      'spread navigation advances by spread while single-page navigation stays linear',
      () {
    expect(
      previousReaderTarget(currentPage: 5, spreadMode: true),
      3,
    );
    expect(
      nextReaderTarget(currentPage: 5, pageCount: 7, spreadMode: true),
      7,
    );
    expect(
      previousReaderTarget(currentPage: 5, spreadMode: false),
      4,
    );
    expect(
      nextReaderTarget(currentPage: 5, pageCount: 7, spreadMode: false),
      6,
    );
  });
}
