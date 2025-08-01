import 'package:flutter/material.dart';
import 'login.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:root_checker_plus/root_checker_plus.dart';
import 'dash.dart';
import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';




void main() async
{

  runApp(const MyApp());
}

class MyApp extends StatefulWidget
{
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp>
{
  //final String IP="192.168.1.2:5000";
  //final String IP="10.12.66.36:5000";
  final String IP="10.12.225.247:5000";

  bool rootedCheck = false;
  bool jailbreak = false;
  bool devMode= false;
  bool _isEmulator = false;
  bool _checked = false;


  @override
  void initState()
  {
    super.initState();
    checkIfEmulator();
    hiveinit();

    if (Platform.isAndroid)
    {
      androidRootChecker();
      developerMode();
      checkDebugger();
    }


    if (Platform.isIOS)
    {
      iosJailbreak();
    }
  }

  Future<void> hiveinit() async
  {
    WidgetsFlutterBinding.ensureInitialized();

    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    // Secure AES key generation/storage
    final secureStorage = FlutterSecureStorage();
    String? keyString = await secureStorage.read(key: 'hive_key');
    if (keyString == null) {
      final key = Hive.generateSecureKey();
      await secureStorage.write(key: 'hive_key', value: key.join(','));
      keyString = key.join(',');
    }

    final encryptionKey = Uint8List.fromList(keyString.split(',').map(int.parse).toList());

    // Open Hive box with encryption
    await Hive.openBox('face_embeddings', encryptionCipher: HiveAesCipher(encryptionKey));
    await Hive.openBox('geoBox', encryptionCipher: HiveAesCipher(encryptionKey));
  }
  void checkDebugger() async {
    bool isDebugging = await isDebuggerConnected();
    if (isDebugging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSimplePopupsign(context, "Debugger is attached!");
      });
    }
  }

  void checkIfEmulator() async {
    bool result = await isEmulator();
    setState(() {
      _isEmulator = result;
      _checked = true;
    });
  }
  Future<bool> isDebuggerConnected() async {
    const platform =MethodChannel('flutter/device_info');
    try {
      final bool isConnected = await platform.invokeMethod('isDebuggerConnected');
      return isConnected;
    } on PlatformException catch (e) {
      print("Failed to check debugger: '${e.message}'.");
      return false;
    }
  }

  Future<bool> isEmulator() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      final model = androidInfo.model?.toLowerCase() ?? '';
      final brand = androidInfo.brand?.toLowerCase() ?? '';
      final device = androidInfo.device?.toLowerCase() ?? '';
      final product = androidInfo.product?.toLowerCase() ?? '';
      final hardware = androidInfo.hardware?.toLowerCase() ?? '';

      return model.contains("emulator") ||
          brand.contains("generic") ||
          device.contains("generic") ||
          product.contains("sdk") ||
          hardware.contains("goldfish") ||
          hardware.contains("ranchu") ||
          hardware.contains("qcom") && product.contains("sdk");
    }

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;

      final simulatorNames = [
        "i386",
        "x86_64",
        "arm64", // Used by Apple silicon simulators
      ];

      final deviceName = iosInfo.name?.toLowerCase() ?? '';
      final machine = iosInfo.utsname.machine?.toLowerCase() ?? '';

      // iOS simulator detection
      return simulatorNames.any((sim) => machine.contains(sim));
    }

    return false; // Unknown platform
  }
  Future<void> androidRootChecker() async {
    try {
      rootedCheck = (await RootCheckerPlus.isRootChecker())!; // return rootcheck status is true or false
    } on PlatformException {
      rootedCheck = false;
    }
    if (!mounted) return;
    setState(() {
      rootedCheck = rootedCheck;
    });
  }
  Future<void> developerMode() async {
    try {
      devMode = (await RootCheckerPlus.isDeveloperMode())!; // return Android developer mode status is true or false
    } on PlatformException {
      devMode = false;
    }
    if (!mounted) return;
    setState(() {
      devMode = devMode;
    });
  }
  Future<void> iosJailbreak() async {
    try {
      jailbreak = (await RootCheckerPlus.isJailbreak())!;  // return iOS jailbreak status is true or false
    } on PlatformException {
      jailbreak = false;
    }
    if (!mounted) return;
    setState(() {
      jailbreak = jailbreak;
    });
  }

  Future<Widget> getInitialPage() async {
    final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

    // Read token from secure storage
    String? token = await secureStorage.read(key: 'token');

    if (token == null) {
      return LoginScreen();
    }

    final url = Uri.parse('http://$IP/verify');
    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      return DashboardScreen(token: token);
    } else {
      await secureStorage.delete(key: 'geo_data_written');
      await secureStorage.delete(key: 'token');
      await Hive.deleteBoxFromDisk('geoBox');
      await secureStorage.delete(key: 'hive_key');
      return LoginScreen();
    }
  }


  void showSimplePopupsign(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Alert"),
          content: Text(
            message,
            textAlign: TextAlign.center, // 👈 center the message
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                SystemNavigator.pop();

              },
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget build(BuildContext context)
  {
    return MaterialApp(
      home: Builder( // needed to get inner context
        builder: (context)
        {
          return FutureBuilder<Widget>(
            future: getInitialPage(),
            builder: (context, snapshot)
            {
              if (rootedCheck)
              {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showSimplePopupsign(context, "Android device is rooted!");
                });
              }
              else if(jailbreak)
              {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showSimplePopupsign(context, "iOS Device is Jail Broken!");
                });
              }
              else if(devMode)
              {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showSimplePopupsign(context, "Device in Developer Mode!");
                });
              }
              // else if(_isEmulator)
              // {
              //   WidgetsBinding.instance.addPostFrameCallback((_) {
              //     showSimplePopupsign(context, "App running on Emulator");
              //   }); // Currently commented out because developing on Android Studio
              // }
              else if (!snapshot.hasData)
              {
                return Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              return snapshot.data!;
            },
          );
        },
      ),
    );
  }
}
