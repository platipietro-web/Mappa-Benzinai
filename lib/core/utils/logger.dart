import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:logger/logger.dart';

final logger = Logger(
  // In produzione disabilita tutti i log: nessun dato personale esposto
  filter: kReleaseMode ? ProductionFilter() : DevelopmentFilter(),
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
  ),
  // In release i livelli sotto WARNING sono silenziati da ProductionFilter
  level: kReleaseMode ? Level.warning : Level.trace,
);

void logInfo(String message) => logger.i(message);
void logError(String message, [dynamic error, StackTrace? stackTrace]) =>
    logger.e(message, error: error, stackTrace: stackTrace);
void logWarning(String message) => logger.w(message);
void logDebug(String message) => logger.d(message);
