import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/update_info.dart';
import 'dart:convert';

class UpdateService {
  static const String _versionUrl = 'https://jnshort.com/version';

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final dio = Dio();
      // Add a timestamp to bypass caching if necessary
      final response = await dio.get(
        _versionUrl,
        options: Options(responseType: ResponseType.json),
      );

      if (response.statusCode == 200) {
        final remoteInfo = UpdateInfo.fromJson(jsonDecode(response.data));
        final packageInfo = await PackageInfo.fromPlatform();

        final currentVersion = packageInfo.version;
        final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

        // Simple version comparison logic
        // You can use pub_semver package for more complex cases
        bool isNewer = false;
        if (_isVersionNewer(remoteInfo.version, currentVersion)) {
          isNewer = true;
        } else if (remoteInfo.version == currentVersion && remoteInfo.build > currentBuild) {
          isNewer = true;
        }

        if (isNewer) {
          return remoteInfo;
        }
      }
    } catch (e) {
      debugPrint('Check for update error: $e');
    }
    return null;
  }

  static bool _isVersionNewer(String remote, String local) {
    List<int> remoteParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> localParts = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < remoteParts.length; i++) {
      if (i >= localParts.length) return true;
      if (remoteParts[i] > localParts[i]) return true;
      if (remoteParts[i] < localParts[i]) return false;
    }
    return false;
  }

  static Future<void> downloadAndInstall({
    required String url,
    required Function(double progress) onProgress,
    required Function(String error) onError,
  }) async {
    try {
      // 1. Check/Request Permission (Android 8+)
      if (Platform.isAndroid) {
        var status = await Permission.requestInstallPackages.status;
        if (status.isDenied) {
          status = await Permission.requestInstallPackages.request();
          if (!status.isGranted) {
            onError('Permission to install unknown apps is required.');
            return;
          }
        }
      }

      final dio = Dio();
      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/app-arm64-v8a-release.apk';

      // Delete old file if exists
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      } else {
        final savePath = '${dir.path}/app-update.apk';
        final file = File(savePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      // 2. Install
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        onError('Could not launch installer: ${result.message}');
      }
    } catch (e) {
      debugPrint('Download error: $e');
      onError(e.toString());
    }
  }
}
