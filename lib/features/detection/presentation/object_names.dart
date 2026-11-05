import 'package:glide/l10n/app_localizations.dart';

/// The detector's (English, COCO) class name in the user's language.
/// Unknown labels are returned unchanged.
String objectName(AppLocalizations l10n, String label) => switch (label) {
  'person' => l10n.objPerson,
  'bicycle' => l10n.objBicycle,
  'car' => l10n.objCar,
  'motorcycle' => l10n.objMotorcycle,
  'bus' => l10n.objBus,
  'truck' => l10n.objTruck,
  'traffic light' => l10n.objTrafficLight,
  'fire hydrant' => l10n.objFireHydrant,
  'stop sign' => l10n.objStopSign,
  'parking meter' => l10n.objParkingMeter,
  'bench' => l10n.objBench,
  'dog' => l10n.objDog,
  'horse' => l10n.objHorse,
  'cow' => l10n.objCow,
  'chair' => l10n.objChair,
  'couch' => l10n.objCouch,
  'potted plant' => l10n.objPottedPlant,
  'dining table' => l10n.objTable,
  'suitcase' => l10n.objSuitcase,
  _ => label,
};
