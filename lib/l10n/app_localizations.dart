import 'package:flutter/material.dart';
class AppLocalizations {
  AppLocalizations(this.locale);
  final Locale locale;
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      AppLocalizations(const Locale('en'));
  static const delegate = _AppLocalizationsDelegate();
  static const supportedLocales = [Locale('en')];
  bool get isArabic => false;
  static const Map<String, String> _strings = {
    'appName': 'Ply',
    'splashSubtitle': 'Smart Video Player',
    'enterSource': 'Enter stream URL or paste MPD XML',
    'urlHint': 'https://example.com/stream.mpd',
    'xmlHint': 'Paste MPD XML content here…',
    'play': 'Play',
    'settings': 'Settings',
    'theme': 'Theme',
    'themeLight': 'Light',
    'themeDark': 'Dark',
    'themeSystem': 'Follow System',
    'appearance': 'Appearance',
    'playerSettings': 'Player Settings',
    'playback': 'Playback',
    'storage': 'Storage & Data',
    'clearCache': 'Clear Cache',
    'cacheCleared': 'Cache cleared successfully',
    'cacheSize': 'Temporary Cache',
    'clearHistory': 'Clear Watch History',
    'historyCleared': 'Watch history cleared',
    'clearHistoryConfirm': 'Are you sure you want to clear all playback history?',
    'defaultFitMode': 'Default Fit Mode',
    'defaultSpeed': 'Default Speed',
    'seekInterval': 'Double-Tap Seek Interval',
    'autoResume': 'Auto-Resume Playback',
    'autoResumeDesc': 'Remember and resume from last position',
    'keepAwake': 'Keep Screen On',
    'keepAwakeDesc': 'Prevent screen timeout during playback',
    'saveThumbnails': 'Save Video Thumbnails',
    'saveThumbnailsDesc': 'Capture previews for history & downloads',
    'confirmDelete': 'Confirm Before Delete',
    'confirmDeleteDesc': 'Show confirmation dialog when deleting items',
    'quality': 'Quality',
    'auto': 'Auto (Adaptive)',
    'speed': 'Speed',
    'volume': 'Volume',
    'brightness': 'Brightness',
    'lock': 'Lock',
    'unlock': 'Unlock',
    'forward10': '+10s',
    'backward10': '-10s',
    'loading': 'Loading…',
    'error': 'Error loading video',
    'selectQuality': 'Select Quality',
    'selectSpeed': 'Playback Speed',
    'screenLocked': 'Screen Locked',
    'doubleTapUnlock': 'Double-tap to unlock',
    'aspectRatio': 'Aspect Ratio',
    'aspectContain': 'Fit (Default)',
    'aspectCover': 'Fill Screen',
    'aspectStretch': 'Stretch',
    'aspect43': '4:3',
    'aspect169': '16:9',
    'loop': 'Loop',
    'loopOn': 'Loop On',
    'loopOff': 'Loop Off',
    'sleepTimer': 'Sleep Timer',
    'sleepTimerOff': 'Off',
    'sleepTimerSet': 'Timer set for',
    'sleepTimerRemaining': 'remaining',
    'sleepTimerCancel': 'Cancel Timer',
    'rotate': 'Rotate',
    'fitMode': 'Fit Mode',
    'autoRotate': 'Auto-Rotate',
    'autoRotateDesc': 'Follow device orientation automatically',
    'download': 'Download',
    'downloadTitlePrompt': 'Enter video title',
    'downloadTitleHint': 'My video',
    'downloadCancel': 'Cancel',
    'downloadStart': 'Download',
    'downloading': 'Downloading…',
    'downloadMerging': 'Merging audio and video…',
    'downloadStarted': 'Download started — check notifications for progress',
    'downloadSuccess': 'Saved to gallery',
    'downloadFailed': 'Download failed',
    'continueWatching': 'Continue Watching',
    'noHistory': 'No videos watched yet',
    'noHistorySubtitle': 'Videos you play will show up here',
    'resume': 'Resume',
    'addNewVideo': 'Add Video',
    'rename': 'Rename',
    'renameVideo': 'Rename video',
    'renameHint': 'New name',
    'delete': 'Delete',
    'deleteFromHistory': 'Remove from history',
    'justNow': 'Just now',
    'minutesAgo': 'm ago',
    'hoursAgo': 'h ago',
    'daysAgo': 'd ago',
    'watched': 'watched',
    'downloads': 'Downloads',
    'noDownloads': 'No downloads yet',
    'noDownloadsSubtitle': 'Videos you download will show up here',
    'deleteDownload': 'Delete download',
    'deleteDownloadConfirm': 'Delete this video from your device?',
    'nowDownloading': 'Downloading',
    'downloadedVideos': 'Downloaded',
    'cancelDownload': 'Cancel',
    'cancelDownloadConfirm': 'Cancel this download?',
    'showLess': 'Show less',
    'searchHint': 'Search history and downloads...',
    'searchEmpty': 'Type to search',
    'searchNoResults': 'No results',
  };
  String get(String key) => _strings[key] ?? key;
  String get appName => get('appName');
  String get splashSubtitle => get('splashSubtitle');
  String get enterSource => get('enterSource');
  String get urlHint => get('urlHint');
  String get xmlHint => get('xmlHint');
  String get play => get('play');
  String get settings => get('settings');
  String get theme => get('theme');
  String get themeLight => get('themeLight');
  String get themeDark => get('themeDark');
  String get themeSystem => get('themeSystem');
  String get appearance => get('appearance');
  String get playerSettings => get('playerSettings');
  String get playback => get('playback');
  String get storage => get('storage');
  String get clearCache => get('clearCache');
  String get cacheCleared => get('cacheCleared');
  String get cacheSize => get('cacheSize');
  String get clearHistoryConfirm => get('clearHistoryConfirm');
  String get historyCleared => get('historyCleared');
  String get defaultFitMode => get('defaultFitMode');
  String get defaultSpeed => get('defaultSpeed');
  String get seekInterval => get('seekInterval');
  String get autoResume => get('autoResume');
  String get autoResumeDesc => get('autoResumeDesc');
  String get keepAwake => get('keepAwake');
  String get keepAwakeDesc => get('keepAwakeDesc');
  String get saveThumbnails => get('saveThumbnails');
  String get saveThumbnailsDesc => get('saveThumbnailsDesc');
  String get confirmDelete => get('confirmDelete');
  String get confirmDeleteDesc => get('confirmDeleteDesc');
  String get quality => get('quality');
  String get auto => get('auto');
  String get speed => get('speed');
  String get volume => get('volume');
  String get brightness => get('brightness');
  String get lock => get('lock');
  String get unlock => get('unlock');
  String get forward10 => get('forward10');
  String get backward10 => get('backward10');
  String get loading => get('loading');
  String get error => get('error');
  String get selectQuality => get('selectQuality');
  String get selectSpeed => get('selectSpeed');
  String get screenLocked => get('screenLocked');
  String get doubleTapUnlock => get('doubleTapUnlock');
  String get aspectRatio => get('aspectRatio');
  String get aspectContain => get('aspectContain');
  String get aspectCover => get('aspectCover');
  String get aspectStretch => get('aspectStretch');
  String get aspect43 => get('aspect43');
  String get aspect169 => get('aspect169');
  String get loop => get('loop');
  String get loopOn => get('loopOn');
  String get loopOff => get('loopOff');
  String get sleepTimer => get('sleepTimer');
  String get sleepTimerOff => get('sleepTimerOff');
  String get sleepTimerSet => get('sleepTimerSet');
  String get sleepTimerRemaining => get('sleepTimerRemaining');
  String get sleepTimerCancel => get('sleepTimerCancel');
  String get rotate => get('rotate');
  String get fitMode => get('fitMode');
  String get autoRotate => get('autoRotate');
  String get autoRotateDesc => get('autoRotateDesc');
  String get download => get('download');
  String get downloadTitlePrompt => get('downloadTitlePrompt');
  String get downloadTitleHint => get('downloadTitleHint');
  String get downloadCancel => get('downloadCancel');
  String get downloadStart => get('downloadStart');
  String get downloadStarted => get('downloadStarted');
  String get downloading => get('downloading');
  String get downloadMerging => get('downloadMerging');
  String get downloadSuccess => get('downloadSuccess');
  String get downloadFailed => get('downloadFailed');
  String get continueWatching => get('continueWatching');
  String get noHistory => get('noHistory');
  String get noHistorySubtitle => get('noHistorySubtitle');
  String get clearHistory => get('clearHistory');
  String get resume => get('resume');
  String get addNewVideo => get('addNewVideo');
  String get rename => get('rename');
  String get renameVideo => get('renameVideo');
  String get renameHint => get('renameHint');
  String get delete => get('delete');
  String get deleteFromHistory => get('deleteFromHistory');
  String get justNow => get('justNow');
  String get minutesAgo => get('minutesAgo');
  String get hoursAgo => get('hoursAgo');
  String get daysAgo => get('daysAgo');
  String get watched => get('watched');
  String get downloads => get('downloads');
  String get noDownloads => get('noDownloads');
  String get noDownloadsSubtitle => get('noDownloadsSubtitle');
  String get deleteDownload => get('deleteDownload');
  String get deleteDownloadConfirm => get('deleteDownloadConfirm');
  String get nowDownloading => get('nowDownloading');
  String get downloadedVideos => get('downloadedVideos');
  String get cancelDownload => get('cancelDownload');
  String get cancelDownloadConfirm => get('cancelDownloadConfirm');
  String get showLess => get('showLess');
  String get searchHint => get('searchHint');
  String get searchEmpty => get('searchEmpty');
  String get searchNoResults => get('searchNoResults');
  String showMore(int n) => 'Show $n more';
}
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';
  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(const Locale('en'));
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
