import 'package:flutter_test/flutter_test.dart';
import 'package:azmusic/data/database/database.dart';

void main() {
  test('in-memory db test', () async {
    final db = AppDatabase.memory();
    print('Opening db...');
    final entries = await db.loadLibraryEntries();
    print('Db entries: ${entries.length}');
    await db.close();
  });
}
