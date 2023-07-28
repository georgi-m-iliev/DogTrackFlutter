import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:app_installer/app_installer.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

int getExtendedVersionNumber(String version) {
  List versionCells = version.split('.');
  versionCells = versionCells.map((i) => int.parse(i)).toList();
  return versionCells[0] * 100000 + versionCells[1] * 1000 + versionCells[2];
}

// singleton class Updater
class Updater {
  static final Updater _updater = Updater.instance();

  factory Updater() {
    return _updater;
  }

  Updater.instance();
  Future<http.Response> fetchData() {
    return http.get(Uri.parse(
      "https://api.github.com/repos/${const String.fromEnvironment('USERNAME_GITHUB')}/${const String.fromEnvironment('REPOSITORY_NAME')}/releases/latest"
    ));
  }

  String parseVersion(dynamic json) {
    return json["tag_name"].toString().substring(1);
  }

  String parseUrl(dynamic json) {
    for(var item in json['assets']) {
      if(item["content_type"] == "application/vnd.android.package-archive") {
        return item["browser_download_url"];
      }
    }
    return "";
  }

  bool isVersionNewer(String remoteVersion, String localVersion) {
    return getExtendedVersionNumber(remoteVersion) > getExtendedVersionNumber(localVersion);
  }

  void downloadAndOpen() async {
    http.Response rawData = await fetchData();
    if(rawData.statusCode == 404) {
      debugPrint("No releases!");
      return;
    }
    dynamic json = jsonDecode(rawData.body);
    
    String version = parseVersion(json);
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    
    if(isVersionNewer(version, packageInfo.version)) {
      debugPrint("New version found: $version. Downloading!");
        Fluttertoast.showToast(
          msg: "Updating...",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          backgroundColor: Colors.red.shade400,
          fontSize: 16.0
        );
      
      String url = parseUrl(json);
      FileDownloader.downloadFile(
        url: url,
        name: "dog-track-update.apk",   
        onDownloadCompleted: (path) {
          debugPrint("Installing...");
          AppInstaller.installApk(path);
        }
      );
    }
    else {
      debugPrint("No new version found!");
    }
  }

  Future<void> cleanup() async {
    debugPrint("Trying to delete apk file...");
    File("/storage/emulated/0/Download/dog-track-update.apk").delete().then(
      (result) {
        debugPrint("Cleanup Success!");
      }
    ).catchError(
      (error) {
        debugPrint("Failed to delete apk file!");
      }
    );
  }

}