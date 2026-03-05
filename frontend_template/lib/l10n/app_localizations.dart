// GENERATED FILE — do not edit by hand.
// Run: flutter gen-l10n
// ignore_for_file: avoid_classes_with_only_static_members
// ignore_for_file: non_constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  String get appTitle;
  String get loginTitle;
  String get username;
  String get password;
  String get serverUrl;
  String get signIn;
  String get signOut;
  String get invalidCredentials;
  String get dashboard;
  String get shifts;
  String get approvals;
  String get settings;
  String get language;
  String get arabic;
  String get english;
  String get save;
  String get submit;
  String get approve;
  String get lock;
  String get status;
  String get notes;
  String get createShift;
  String get reportDate;
  String get shiftCode;
  String get open;
  String get refresh;
  String get unitBlow;
  String get unitFilling;
  String get unitLabel;
  String get unitShrink;
  String get unitDiesel;
  String get unitSummary;
  String get prev;
  String get received;
  String get next;
  String get product;
  String get waste;
  String get counter;
  String get cartons;
  String get rolls;
  String get kg;
  String get grams;
  String get pcs;
  String get preformsPerCarton;
  String get capsPerCarton;
  String get labelsPerRoll;
  String get kgPerRoll;
  String get kgPerCarton;
  String get wastePercent;
  String get shortagePercent;
  String get mainTankReceived;
  String get generator1;
  String get generator2;
  String get totalReading;
  String get consumedLiters;
  String get permissionDenied;
  String get summary;
  String get warehouses;
  String get warehouse;
  String get stockOnHand;
  String get transactions;
  String get newTransaction;
  String get item;
  String get quantity;
  String get transactionType;
  String get noPendingApprovals;
  String get rawWarehouse;
  String get fgWarehouse;
  String get fuelWarehouse;
  String get productionHall;
  String get receiveGoods;
  String get transferToProduction;
  String get transferToFG;
  String get issueGoods;
  String get receiveFinished;
  String get issueFuel;
  String get receiveFuel;
  String get generator;
  String get pendingTransactions;
  String get acknowledgedTransactions;
  String get postedTransactions;
  String get acknowledge;
  String get post;
  String get accountantDashboard;
  String get controllerDashboard;
  String get managerDashboard;
  String get auditorDashboard;
  String get allOperations;
  String get sourceWarehouse;
  String get targetWarehouse;
  String get transferQty;
  String get invoiceRef;
  String get txnPending;
  String get txnAcknowledged;
  String get txnPosted;
  String get noTransactions;
  String get confirmAcknowledge;
  String get confirmPost;
  String get yes;
  String get no;
  String get error;
  String get success;
  String get loading;
  String get date;
  String get type;
  String get myWarehouse;
  String get allWarehouses;
  String get shiftReports;
  String get warehouseMovements;
  String get productionSupervisorDashboard;
  String get receiveFromRM;
  String get shiftCreateButton;
  String get shiftDate;
  String get shiftCodeLabel;
  String get stockReport;
  String get allTransactions;
  String get transferPair;
  String get receiveTitle;
  String get issueTitle;
  String get syncOffline;
  String get syncSyncing;
  String get syncUpToDate;
  String syncPendingCount(String count);
  String get syncJustNow;
  String syncMinutesAgo(String n);
  String syncHoursAgo(String n);
  String get syncNow;
  String get syncError;
  String get savedOffline;
  String get noData;
  String get syncConflictTitle;
  String syncConflictSubtitle(String count);
  String get syncConflictResolved;
  String get syncConflictUnknownError;
  String get syncConflictRetry;
  String get syncConflictDiscard;
  String get close;
  String get dateFrom;
  String get dateTo;
  String get filterByDate;
  String get clearFilter;
  String syncShiftPending(String count);
  String get submitRequiresConnection;
  String get approveRequiresConnection;
  String get lockRequiresConnection;
  String get offlineCachedData;

  String get localeName_;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(_lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations _lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
  }
  throw FlutterError('AppLocalizations.delegate failed to load unsupported locale "$locale"');
}