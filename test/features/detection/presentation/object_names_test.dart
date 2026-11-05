import 'package:flutter_test/flutter_test.dart';
import 'package:glide/features/detection/domain/usecases/distance_estimator.dart';
import 'package:glide/features/detection/presentation/object_names.dart';
import 'package:glide/l10n/app_localizations_en.dart';
import 'package:glide/l10n/app_localizations_es.dart';

void main() {
  test('every obstacle class has a translated name', () {
    final es = AppLocalizationsEs();
    for (final label in DistanceEstimator.typicalHeights.keys) {
      expect(objectName(es, label), isNot(label), reason: label);
    }
  });

  test('names are spoken naturally and unknown labels pass through', () {
    final en = AppLocalizationsEn();
    expect(objectName(en, 'couch'), 'sofa');
    expect(objectName(AppLocalizationsEs(), 'bench'), 'banco');
    expect(objectName(en, 'zebra'), 'zebra');
  });
}
