import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:html/parser.dart';
import 'package:sph_plan/client/client_submodules/datastorage.dart';
import 'package:sph_plan/client/client_submodules/mein_unterricht.dart';
import 'package:sph_plan/shared/exceptions/client_status_exceptions.dart';
import 'package:sph_plan/client/storage.dart';
import 'package:sph_plan/client/cryptor.dart';
import 'package:sph_plan/client/fetcher.dart';
import 'package:sph_plan/themes.dart';

import '../shared/apps.dart';
import '../shared/shared_functions.dart';
import '../shared/types/fach.dart';
import '../shared/types/upload.dart';
import 'client_submodules/calendar.dart';
import 'client_submodules/substitutions.dart';

class SPHclient {
  final statusCodes = {
    0: "Alles supper Brudi!",
    -1: "Falsche Anmeldedaten",
    -2: "Nicht alle Anmeldedaten angegeben",
    -3: "Netzwerkfehler",
    -4: "Unbekannter Fehler! Bist du eingeloggt?",
    -5: "Keine Erlaubnis",
    -6: "Verschlüsselungsüberprüfung fehlgeschlagen",
    -7: "Unbekannter Fehler! Antwort war nicht salted.",
    -8: "Nicht unterstützt!",
    -9: "Kein Internet."
  };

  String username = "";
  String password = "";
  String schoolID = "";
  String schoolName = "";
  String schoolImage = "";
  String loadMode = "";
  dynamic userData = {};
  List<dynamic> supportedApps = [];
  late CookieJar jar;
  final dio = Dio();
  Timer? timer;
  late Cryptor cryptor = Cryptor();

  late SubstitutionsParser substitutions = SubstitutionsParser(dio, this);
  late CalendarParser calendar = CalendarParser(dio, this);
  late DataStorageParser dataStorage = DataStorageParser(dio, this);
  late MeinUnterrichtParser meinUnterricht = MeinUnterrichtParser(dio, this);

  SubstitutionsFetcher? substitutionsFetcher;
  MeinUnterrichtFetcher? meinUnterrichtFetcher;
  VisibleConversationsFetcher? visibleConversationsFetcher;
  InvisibleConversationsFetcher? invisibleConversationsFetcher;
  CalendarFetcher? calendarFetcher;

  void prepareFetchers() {
    if (client.loadMode == "full") {
      if (client.doesSupportFeature(SPHAppEnum.vertretungsplan) && substitutionsFetcher == null) {
        substitutionsFetcher = SubstitutionsFetcher(const Duration(minutes: 15));
      }
      if (client.doesSupportFeature(SPHAppEnum.meinUnterricht) && meinUnterrichtFetcher == null) {
        meinUnterrichtFetcher = MeinUnterrichtFetcher(const Duration(minutes: 15));
      }
      if (client.doesSupportFeature(SPHAppEnum.nachrichten)) {
        visibleConversationsFetcher ??= VisibleConversationsFetcher(const Duration(minutes: 15));
        invisibleConversationsFetcher ??= InvisibleConversationsFetcher(const Duration(minutes: 15));
      }
      if (client.doesSupportFeature(SPHAppEnum.kalender) && calendarFetcher == null) {
        calendarFetcher = CalendarFetcher(null);
      }
    } else {
      if (client.doesSupportFeature(SPHAppEnum.vertretungsplan) && substitutionsFetcher == null) {
        substitutionsFetcher = SubstitutionsFetcher(null);
      }
      if (client.doesSupportFeature(SPHAppEnum.meinUnterricht) && meinUnterrichtFetcher == null) {
        meinUnterrichtFetcher = MeinUnterrichtFetcher(null);
      }
      if (client.doesSupportFeature(SPHAppEnum.nachrichten)) {
        visibleConversationsFetcher ??= VisibleConversationsFetcher(null);
        invisibleConversationsFetcher ??= InvisibleConversationsFetcher(null);
      }
      if (client.doesSupportFeature(SPHAppEnum.kalender) && calendarFetcher == null) {
        calendarFetcher = CalendarFetcher(null);
      }
    }
  }

  Future<void> prepareDio() async {
    jar = CookieJar();
    dio.interceptors.add(CookieManager(jar));
    dio.options.followRedirects = false;
    dio.options.validateStatus =
        (status) => status != null && (status == 200 || status == 302);
  }

  Future<void> overwriteCredits(String username, String password,
      String schoolID) async {
    this.username = username;
    this.password = password;
    this.schoolID = schoolID;

    await globalStorage.write(key: StorageKey.userUsername, value: username);
    await globalStorage.write(key: StorageKey.userPassword, value: password, secure: true);
    await globalStorage.write(key: StorageKey.userSchoolID, value: schoolID);
  }


  Future<void> loadFromStorage() async {
    loadMode = await globalStorage.read(key: StorageKey.settingsLoadMode);

    username = await globalStorage.read(key: StorageKey.userUsername);
    password = await globalStorage.read(key: StorageKey.userPassword, secure: true);
    schoolID = await globalStorage.read(key: StorageKey.userSchoolID);

    //path
    final Directory dir = await getApplicationDocumentsDirectory();
    String fileName = "school.jpg";
    schoolImage = "${dir.path}/$fileName";

    schoolName = await globalStorage.read(key: StorageKey.userSchoolName);

    userData = jsonDecode(await globalStorage.read(key: StorageKey.userData));

    supportedApps =
        jsonDecode(await globalStorage.read(key: StorageKey.userSupportedApplets));
  }

  Future<dynamic> getCredits() async {
    return {
      "username": await globalStorage.read(key: StorageKey.userUsername),
      "password": await globalStorage.read(key: StorageKey.userPassword, secure: true),
      "schoolID": await globalStorage.read(key: StorageKey.userSchoolID),
      "schoolName": await globalStorage.read(key: StorageKey.userSchoolName),
    };
  }

  Future<void> login({userLogin = false}) async {
    debugPrint("Trying to log in");

    if (!(await InternetConnectionChecker().hasConnection)) {
      throw NoConnectionException();
    }

    jar.deleteAll();
    dio.options.validateStatus =
        (status) => status != null && (status == 200 || status == 302);
    try {
      if (username != "" && password != "" && schoolID != "") {
        final response1 = await dio.post(
            "https://login.schulportal.hessen.de/?i=$schoolID",
            queryParameters: {
              "user": '$schoolID.$username',
              "user2": username,
              "password": password
            },
            options: Options(contentType: "application/x-www-form-urlencoded"));
        if (response1.headers.value(HttpHeaders.locationHeader) != null) {
          //credits are valid
          final response2 =
              await dio.get("https://connect.schulportal.hessen.de");

          String location2 =
              response2.headers.value(HttpHeaders.locationHeader) ?? "";
          await dio.get(location2);

          timer?.cancel();
          timer = Timer.periodic(const Duration(seconds: 60), (timer) => preventLogout());

          if (userLogin) {
            await fetchRedundantData();
          }
          await getSchoolTheme();

          int encryptionStatusName = await cryptor.start(dio);
          debugPrint("Encryption connected with status code: $encryptionStatusName");

          return;
        } else {
          throw WrongCredentialsException();
        }
      } else {
        throw CredentialsIncompleteException();
      }
    } on SocketException {
      throw NetworkException();
    } on DioException {
      throw NetworkException();
    } on LanisException {
      rethrow;
    } catch (e, stack) {
      recordError(e, stack);
      debugPrint(e.toString());
      throw LoggedOffOrUnknownException();
    }
  }

  Future<void> preventLogout() async {
    final uri = Uri.parse("https://start.schulportal.hessen.de/ajax_login.php");
    var sid = (await jar.loadForRequest(uri)).firstWhere((element) => element.name == "sid").value;
    debugPrint("Refreshing session");
    try {
      await dio.post("https://start.schulportal.hessen.de/ajax_login.php",
          queryParameters: {
            "name": sid
          },
          options: Options(contentType: "application/x-www-form-urlencoded"));
    } on DioException {
      return;
    }
  }

  Future<void> fetchRedundantData() async {
    final schoolInfo = await getSchoolInfo(schoolID);

    schoolImage = await getSchoolImage(schoolInfo["bgimg"]["sm"]["url"]);
    await globalStorage.write(key: StorageKey.schoolImageLocation, value: schoolImage);

    schoolName = schoolInfo["Name"];
    await globalStorage.write(key: StorageKey.userSchoolName, value: schoolName);

    userData = await fetchUserData();
    supportedApps = await getSupportedApps();

    await globalStorage.write(key: StorageKey.userData, value: jsonEncode(userData));

    await globalStorage.write(
        key: StorageKey.userSupportedApplets, value: jsonEncode(supportedApps));
  }

  Future<void> getSchoolTheme() async {
    debugPrint("Trying to get a school accent color.");

    if (await globalStorage.read(key: StorageKey.schoolAccentColor) == "") {
      try {
        dynamic schoolInfo = await client.getSchoolInfo(schoolID);

        int schoolColor = int.parse("FF${schoolInfo["Farben"]["bg"].substring(1)}", radix: 16);

        Themes.schoolTheme = Themes.getNewTheme(Color(schoolColor));

        if ((await globalStorage.read(key: StorageKey.settingsSelectedColor)) == "school") {
          ColorModeNotifier.set("school", Themes.schoolTheme);
        }

        await globalStorage.write(key: StorageKey.schoolAccentColor, value: schoolColor.toString());
      } on Exception catch (_) {}
    }
  }

  Future<String> getSchoolImage(String url) async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory();

      String fileName = "school.jpg";
      String savePath = "${dir.path}/$fileName";

      Directory folder = Directory(dir.path);
      if (!(await folder.exists())) {
        await folder.create(recursive: true);
      }

      File existingFile = File(savePath);
      if (await existingFile.exists()) {
        return savePath;
      }

      await dio.download(
        url,
        savePath,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          headers: {
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
            "Sec-Fetch-Dest": "document",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "none",
          },
        ),
      );

      return savePath;
    } catch (e, stack) {
      recordError(e, stack);
      return "";
    }
  }

  Future<String> getLoginURL() async {
    final dioHttp = Dio();
    final cookieJar = CookieJar();
    dioHttp.interceptors.add(CookieManager(cookieJar));
    dioHttp.options.followRedirects = false;
    dioHttp.options.validateStatus =
        (status) => status != null && (status == 200 || status == 302);

    try {
      if (username != "" && password != "" && schoolID != "") {
        final response1 = await dioHttp.post(
            "https://login.schulportal.hessen.de/?i=$schoolID",
            queryParameters: {
              "user": '$schoolID.$username',
              "user2": username,
              "password": password
            },
            options: Options(contentType: "application/x-www-form-urlencoded"));
        if (response1.headers.value(HttpHeaders.locationHeader) != null) {
          //credits are valid
          final response2 =
              await dioHttp.get("https://connect.schulportal.hessen.de");

          String location2 =
              response2.headers.value(HttpHeaders.locationHeader) ?? "";

          return location2;
        } else {
          throw WrongCredentialsException();
        }
      } else {
        throw CredentialsIncompleteException();
      }
    } catch (e, stack) {
      recordError(e, stack);
      throw LoggedOffOrUnknownException();
    }
  }

  Future<List<List<List<StdPlanFach>>>> getStundenplan() async {
    final location = await dio.get("https://start.schulportal.hessen.de/stundenplan.php");
    final response = await dio.get("https://start.schulportal.hessen.de/${location.headers["location"]![0]}");

    var document = parse(response.data);
    var stundenplanTableHead = document.querySelector("#own thead");

    var sk = stundenplanTableHead!.querySelector("th")!.text.contains("Stunde");

    var stundenplanTableBody = document.querySelector("#own tbody");

    if (stundenplanTableBody != null) {
      List<List<List<StdPlanFach>>> result = [];

      for (var row in stundenplanTableBody.querySelectorAll("tr")) {
        if (row.text.replaceAll(RegExp(r'[\s\n\r]'), "") == "") continue;
        List<List<StdPlanFach>> timeslot = [];
        for (var (index, day) in row.querySelectorAll("td").indexed) {
          if (sk && index == 0) continue;
          List<StdPlanFach> stunde = [];
          for (var fach in day.querySelectorAll(".stunde")) {
            var name = fach.querySelector("b")!.text.trim();
            var raum = fach.nodes.map((node) => node.nodeType == 3 ? node.text!.trim() : "").join();
            var lehrer = fach.querySelector("small")!.text.trim();
            var badge = fach.querySelector(".badge")?.text.trim() ?? "";
            var duration = int.parse(fach.parent!.attributes["rowspan"]!);
            stunde.add(StdPlanFach(name, raum, lehrer, badge, duration));
          }
          timeslot.add(stunde);
        }
        result.add(timeslot);
      }
      return result;
    } else {
      return [];
    }
  }

  Future<bool> isAuth() async {
    try {
      final response = await dio.get(
          "https://start.schulportal.hessen.de/benutzerverwaltung.php?a=userData");
      String responseText = response.data.toString();
      if (responseText.contains("Fehler - Schulportal Hessen") ||
          username.isEmpty ||
          password.isEmpty ||
          schoolID.isEmpty) {
        return false;
      } else if (responseText.contains(username)) {
        return true;
      } else {
        return false;
      }
    } catch (e, stack) {
      recordError(e, stack);
      return false;
    }
  }

  Future<dynamic> getSchoolInfo(String schoolID) async {
    final response = await dio.get(
        "https://startcache.schulportal.hessen.de/exporteur.php?a=school&i=$schoolID");
    return jsonDecode(response.data.toString());
  }

  Future<dynamic> getSupportedApps() async {
    final response = await dio.get(
        "https://start.schulportal.hessen.de/startseite.php?a=ajax&f=apps");
    return jsonDecode(response.data.toString())["entrys"];
  }

  bool doesSupportFeature(SPHAppEnum feature) {
    var app = supportedApps.where((element) => element["link"].toString() == feature.php).singleOrNull;
    if (app == null) return false;
    if (feature.onlyStudents) {
      return isStudentAccount();
    } else {
      return true;
    }
  }

  bool isStudentAccount() {
    return userData.containsKey("klasse");
  }

  Future<dynamic> fetchUserData() async {
    final response = await dio.get(
        "https://start.schulportal.hessen.de/benutzerverwaltung.php?a=userData");
    var document = parse(response.data);
    var userDataTableBody =
        document.querySelector("div.col-md-12 table.table.table-striped tbody");

    //TODO find out how "Zugeordnete Eltern/Erziehungsberechtigte" is used in this scope

    if (userDataTableBody != null) {
      var result = {};

      var rows = userDataTableBody.querySelectorAll("tr");
      for (var row in rows) {
        var key = row.children[0].text.trim();
        var value = row.children[1].text.trim();

        key = (key.substring(0, key.length - 1)).toLowerCase();

        result[key] = value;
      }

      return result;
    } else {
      return {};
    }
  }

  Future<void> deleteAllSettings() async {
    jar.deleteAll();
    globalStorage.deleteAll();
    ColorModeNotifier.set("standard", Themes.standardTheme);
    ThemeModeNotifier.set("system");

    var tempDir = await getTemporaryDirectory();
    await deleteSubfoldersAndFiles(tempDir);
  }

  Future<void> deleteSubfoldersAndFiles(Directory directory) async {
    await for (var entity in directory.list()) {
      if (entity is File) {
        await entity.delete(recursive: true);
      } else if (entity is Directory) {
        await deleteSubfoldersAndFiles(entity);
        await entity.delete(recursive: true);
      }
    }
  }

  Future<dynamic> getConversationsOverview(bool invisible) async {
    if (!(client.doesSupportFeature(SPHAppEnum.nachrichten))) {
      return -8;
    }

    debugPrint("Get new conversation data. Invisible: $invisible.");
    try {
      final response =
          await dio.post("https://start.schulportal.hessen.de/nachrichten.php",
              data: {
                "a": "headers",
                "getType": invisible ? "unvisibleOnly" : "visibleOnly",
                "last": "0"
              },
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Content-Type":
                      "application/x-www-form-urlencoded; charset=UTF-8",
                  "Sec-Fetch-Dest": "empty",
                  "Sec-Fetch-Mode": "cors",
                  "Sec-Fetch-Site": "same-origin",
                  "X-Requested-With": "XMLHttpRequest",
                },
              ));

      final Map<String, dynamic> encryptedJSON =
          jsonDecode(response.toString());

      final String? decryptedConversations =
          cryptor.decryptString(encryptedJSON["rows"]);

      if (decryptedConversations == null) {
        return -7;
        // unknown error (encrypted isn't salted)
      }

      return jsonDecode(decryptedConversations);
    } on (SocketException, DioException) {
      return -3;
      // network error
    } catch (e, stack) {
      recordError(e, stack);
      return -4;
      // unknown error
    }
  }

  String generateUniqueHash(String source) {
    var bytes = utf8.encode(source);
    var digest = sha256.convert(bytes);

    var shortHash = digest.toString().replaceAll(RegExp(r'[^A-z0-9]'), '').substring(0, 6);

    return shortHash;
  }

  Future<String> downloadFile(String url, String filename) async {
    try {
      var tempDir = await getTemporaryDirectory();

      // To ensure unique file names, we store each file in a folder
      // with a hashed value of the download URL.
      // It is necessary for a teacher to upload files with unique file names.
      String urlHash = generateUniqueHash(url);

      String folderPath = "${tempDir.path}/$urlHash";
      String savePath = "$folderPath/$filename";

      // Check if the folder exists, create it if not
      Directory folder = Directory(folderPath);
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }

      // Check if the file already exists
      File existingFile = File(savePath);
      if (existingFile.existsSync()) {
        return savePath;
      }

      Response response = await dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
        ),
      );

      File file = File(savePath);
      var raf = file.openSync(mode: FileMode.write);
      raf.writeFromSync(response.data);
      await raf.close();

      return savePath;
    } catch (e, stack) {
      recordError(e, stack);
      return "";
    }
  }

  Future<dynamic> deleteUploadedFile({
    required String course,
    required String entry,
    required String upload,
    required String file,
    required String userPasswordEncrypted
  }) async {
    try {
      final response = await dio.post(
          "https://start.schulportal.hessen.de/meinunterricht.php",
          data: {
            "a": "sus_abgabe",
            "d": "delete",
            "b": course,
            "e": entry,
            "id": upload,
            "f": file,
            "pw": userPasswordEncrypted
          },
          options: Options(
            headers: {
              "Accept": "*/*",
              "Content-Type":
              "application/x-www-form-urlencoded; charset=UTF-8",
              "Sec-Fetch-Dest": "empty",
              "Sec-Fetch-Mode": "cors",
              "Sec-Fetch-Site": "same-origin",
              "X-Requested-With": "XMLHttpRequest",
            },
          )
      );

      // "-1" Wrong password
      // "-2" Delete was not possible
      // "0" Unknown error
      // "1" Lanis had a good day
      return response.data;
     }on (SocketException, DioException) {
      return -3;
      // network error
    } catch (e, stack) {
      recordError(e, stack);
      return -4;
      // unknown error
    }
  }

  Future<dynamic> getUploadInfo(String url) async {
    try {
      final response = await dio.get(url);
      final parsed = parse(response.data);

      final requirementsGroup = parsed.querySelectorAll("div#content div.row div.col-md-12")[1];

      final String? start = requirementsGroup.querySelector("span.editable")?.text.trim().replaceAll(" ab", "");
      final String? deadline = requirementsGroup.querySelector("b span.editable")?.text.trim().replaceAll("  spätestens", "");
      final bool uploadMultipleFiles = requirementsGroup.querySelectorAll("i.fa.fa-check-square-o.fa-fw + span.label.label-success")[0].text.trim() == "erlaubt" ? true : false;
      final bool uploadAnyNumberOfTimes = requirementsGroup.querySelectorAll("i.fa.fa-check-square-o.fa-fw + span.label.label-success")[1].text.trim() == "erlaubt" ? true : false;
      final String? visibility = requirementsGroup.querySelector("i.fa.fa-eye.fa-fw + span.label")?.text.trim() ?? requirementsGroup.querySelector("i.fa.fa-eye-slash.fa-fw + span.label")?.text.trim() ;
      final String? automaticDeletion = requirementsGroup.querySelector("i.fa.fa-trash-o.fa-fw + span.label.label-info")?.text.trim();
      final List<String> allowedFileTypes = requirementsGroup.querySelectorAll("i.fa.fa-file.fa-fw + span.label.label-warning")[0].text.trim().split(", ");
      final String maxFileSize = requirementsGroup.querySelectorAll("i.fa.fa-file.fa-fw + span.label.label-warning")[1].text.trim();
      final String? additionalText = requirementsGroup.querySelector("div.alert.alert-info")?.text.split("\n")[1].trim();

      final ownFilesGroup = parsed.querySelectorAll("div#content div.row div.col-md-12")[2];
      final List<OwnFile> ownFiles = [];
      for (final group in ownFilesGroup.querySelectorAll("ul li")) {
        final fileIndex = RegExp(r"f=(\d+)");

        ownFiles.add(
            OwnFile(
                name: group.querySelector("a")!.text.trim(),
                url: "https://start.schulportal.hessen.de/${group.querySelector("a")!.attributes["href"]!}",
                time: group.querySelector("small")!.text,
                index: fileIndex.firstMatch(group.querySelector("a")!.attributes["href"]!)!.group(1)!,
                comment: group.nodes.elementAtOrNull(10) != null ? group.nodes[10].text!.trim() : null
            )
        );
      }

      final uploadForm = parsed.querySelector("div.col-md-7 form");
      String? courseId;
      String? entryId;
      String? uploadId;

      if (uploadForm != null) {
        courseId = uploadForm.querySelector("input[name='b']")!.attributes["value"]!;
        entryId = uploadForm.querySelector("input[name='e']")!.attributes["value"]!;
        uploadId = uploadForm.querySelector("input[name='id']")!.attributes["value"]!;
      }

      final publicFilesGroup = parsed.querySelector("div#content div.row div.col-md-5");
      final List<PublicFile> publicFiles = [];

      if (publicFilesGroup != null) {
        for (final group in publicFilesGroup.querySelectorAll("ul li")) {
          final fileIndex = RegExp(r"f=(\d+)");

          publicFiles.add(
              PublicFile(
                name: group.querySelector("a")!.text.trim(),
                url: "https://start.schulportal.hessen.de/${group.querySelector("a")!.attributes["href"]!}",
                person: group.querySelector("span.label.label-info")!.text.trim(),
                index: fileIndex.firstMatch(group.querySelector("a")!.attributes["href"]!)!.group(1)!,
              )
          );
        }
      }

      return {
        "start": start,
        "deadline": deadline,
        "upload_multiple_files": uploadMultipleFiles,
        "upload_any_number_of_times": uploadAnyNumberOfTimes,
        "visibility": visibility,
        "automatic_deletion": automaticDeletion,
        "allowed_file_types": allowedFileTypes,
        "max_file_size": maxFileSize,
        "course_id": courseId,
        "entry_id": entryId,
        "upload_id": uploadId,
        "own_files": ownFiles,
        "public_files": publicFiles,
        "additional_text": additionalText,
      };
    } on (SocketException, DioException) {
      return -3;
      // network error
    } catch (e, stack) {
      recordError(e, stack);
      return -4;
      // unknown error
    }
  }

  Future<dynamic> uploadFile(
      {
        required String course,
        required String entry,
        required String upload,
        required MultipartFile file1,
        MultipartFile? file2,
        MultipartFile? file3,
        MultipartFile? file4,
        MultipartFile? file5,
      }) async {

    try {
      final FormData uploadData = FormData.fromMap({
        "a": "sus_abgabe",
        "b": course,
        "e": entry,
        "id": upload,
        "file1": file1,
        "file2": file2,
        "file3": file3,
        "file4": file4,
        "file5": file5
      });

      final response = await dio.post(
          "https://start.schulportal.hessen.de/meinunterricht.php",
          data: uploadData,
          options: Options(
              headers: {
                "Accept": "*/*",
                "Content-Type": "multipart/form-data;",
                "Sec-Fetch-Dest": "document",
                "Sec-Fetch-Mode": "navigate",
                "Sec-Fetch-Site": "same-origin",
              }
          )
      );

      final parsed = parse(response.data);

      final statusMessagesGroup = parsed.querySelectorAll("div#content div.col-md-12")[2];

      final List<FileStatus> statusMessages = [];
      for (final statusMessage in statusMessagesGroup.querySelectorAll("ul li")) {
        statusMessages.add(FileStatus(
          name: statusMessage.querySelector("b")!.text.trim(),
          status: statusMessage.querySelector("span.label")!.text.trim(),
          message: statusMessage.nodes[4].text?.trim(),
        ));
      }

      return statusMessages;
    } on (SocketException, DioException) {
      return -3;
      // network error
    } catch (e, stack) {
      recordError(e, stack);
      return -4;
      // unknown error
    }
  }

  Future<dynamic> getSingleConversation(String uniqueID) async {
    if (!(await InternetConnectionChecker().hasConnection)) {
      return -9;
    }

    try {
      final encryptedUniqueID = cryptor.encryptString(uniqueID);

      final response =
          await dio.post("https://start.schulportal.hessen.de/nachrichten.php",
              queryParameters: {"a": "read", "msg": uniqueID},
              data: {"a": "read", "uniqid": encryptedUniqueID},
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Content-Type":
                      "application/x-www-form-urlencoded; charset=UTF-8",
                  "Sec-Fetch-Dest": "empty",
                  "Sec-Fetch-Mode": "cors",
                  "Sec-Fetch-Site": "same-origin",
                  "X-Requested-With": "XMLHttpRequest",
                },
              ));

      final Map<String, dynamic> encryptedJSON =
          jsonDecode(response.toString());

      final String? decryptedConversations =
          cryptor.decryptString(encryptedJSON["message"]);

      if (decryptedConversations == null) {
        return -7;
        // unknown error (encrypted isn't salted)
      }

      return jsonDecode(decryptedConversations);
    } on (SocketException, DioException) {
      return -3;
      // network error
    }
  }
}

SPHclient client = SPHclient();
