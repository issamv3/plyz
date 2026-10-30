import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_flutter/lucide_flutter.dart';
class SmartErrorInfo {
  final String title;
  final String message;
  final IconData icon;
  final bool isNetworkError;
  final bool isAuthError;
  final bool isNotFoundError;
  final bool isSignatureExpired;
  final bool canOpenBrowser;
  final bool canRetry;
  const SmartErrorInfo({
    required this.title,
    required this.message,
    required this.icon,
    this.isNetworkError = false,
    this.isAuthError = false,
    this.isNotFoundError = false,
    this.isSignatureExpired = false,
    this.canOpenBrowser = true,
    this.canRetry = true,
  });
}
class SmartError {
  static SmartErrorInfo analyze(dynamic error, {String? url}) {
    if (error == null) {
      return const SmartErrorInfo(
        title: 'Unable to Play Video',
        message: 'An unexpected issue occurred while preparing the video. Please try again.',
        icon: LucideIcons.alertCircle,
      );
    }
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('url signature expired') ||
        errStr.contains('signature expired') ||
        errStr.contains('signature_expired') ||
        errStr.contains('sig expired') ||
        errStr.contains('signature is expired')) {
      return const SmartErrorInfo(
        title: 'URL Signature Expired',
        message: 'The streaming links in this DASH stream have expired (URL signature expired). Please provide a fresh link or re-extract the video.',
        icon: LucideIcons.clockAlert,
        isSignatureExpired: true,
        canOpenBrowser: true,
        canRetry: true,
      );
    }
    if (error is SocketException ||
        error is HandshakeException ||
        error is TimeoutException ||
        error is http.ClientException ||
        errStr.contains('socketexception') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('network is unreachable') ||
        errStr.contains('no address associated with hostname') ||
        errStr.contains('connection refused') ||
        errStr.contains('connection timed out') ||
        errStr.contains('connection reset') ||
        errStr.contains('software caused connection abort') ||
        errStr.contains('handshakeexception') ||
        errStr.contains('certificate_verify_failed') ||
        errStr.contains('timeoutexception') ||
        errStr.contains('no internet') ||
        errStr.contains('offline') ||
        errStr.contains('dns')) {
      return const SmartErrorInfo(
        title: 'No Internet Connection',
        message: 'Please check your internet connection and network settings, then try again.',
        icon: LucideIcons.wifiOff,
        isNetworkError: true,
        canOpenBrowser: false,
        canRetry: true,
      );
    }
    if (errStr.contains('login') ||
        errStr.contains('checkpoint') ||
        errStr.contains('session') ||
        errStr.contains('dtsg') ||
        errStr.contains('private') ||
        errStr.contains('unauthorized') ||
        errStr.contains('access denied') ||
        errStr.contains('forbidden') ||
        errStr.contains('401') ||
        (errStr.contains('403') && !errStr.contains('expired'))) {
      return const SmartErrorInfo(
        title: 'Login Required',
        message: 'This video may be private or restricted to logged-in users. Open the browser to sign in and view it.',
        icon: LucideIcons.lock,
        isAuthError: true,
        canOpenBrowser: true,
        canRetry: true,
      );
    }
    if (errStr.contains('not found') ||
        errStr.contains('could not extract video id') ||
        errStr.contains('could not extract video') ||
        errStr.contains('404') ||
        errStr.contains('deleted') ||
        errStr.contains('removed') ||
        errStr.contains('invalid url') ||
        errStr.contains('does not exist') ||
        errStr.contains('unavailable') ||
        errStr.contains('unsupported')) {
      return const SmartErrorInfo(
        title: 'Video Unavailable',
        message: 'This video could not be found. It may have been removed, made private, or the link is invalid.',
        icon: LucideIcons.videoOff,
        isNotFoundError: true,
        canOpenBrowser: true,
        canRetry: false,
      );
    }
    if (errStr.contains('429') ||
        errStr.contains('rate limit') ||
        errStr.contains('too many requests') ||
        errStr.contains('temporary block')) {
      return const SmartErrorInfo(
        title: 'Too Many Requests',
        message: 'Requests are temporarily being rate-limited. Please wait a few moments before trying again.',
        icon: LucideIcons.clock,
        canOpenBrowser: true,
        canRetry: true,
      );
    }
    return const SmartErrorInfo(
      title: 'Extraction Error',
      message: 'Could not load video streams from this link. You can open the built-in browser to view it directly.',
      icon: LucideIcons.alertCircle,
      canOpenBrowser: true,
      canRetry: true,
    );
  }
}
