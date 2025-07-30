import 'package:flutter/material.dart';
import 'dash.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'coordinate_storage.dart';
import 'package:hive/hive.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers for TextField
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  //final String IP='192.168.1.2:5000';
  //final String IP="10.12.66.36:5000";
  final String IP="10.12.225.247:5000";

  // Form Key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    // Dispose controllers to free resources
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<String> _fetchDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        const platform = MethodChannel('flutter/device_info');
        String? androidId = await platform.invokeMethod('getAndroidId');
        return androidId ?? 'Unknown';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'Unknown';
      } else {
        return 'Unsupported platform';
      }
    } catch (e) {
      return 'Failed to get device ID';
    }
  }


  void _signIn() async {
    if (_formKey.currentState!.validate()) {
      // Fetch username and password if needed:
      String username = usernameController.text;
      String password = passwordController.text;
      String id= await _fetchDeviceId();
        // Perform login logic here (if any)
        // final url='http://10.0.2.2:5000/login?rollno=$username&pass=$password';
      if(id=='Unknown' || id=='Unsupported platform')
        {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unsupported device')),
          );
          return;
        }
      else if(id=='Failed to get device ID')
        {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to get device ID, try again')),
          );
          return;
        }


        // final url='http://10.12.178.137:5000/login?rollno=$username&pass=$password&id=$id';
        // final url='http://192.168.1.2:5000/login?rollno=$username&pass=$password&id=$id';
      final url=Uri.parse('http://$IP/login');
        //printToConsole(url);
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'rollno': username,
            'pass': password,
            'id': id,
          }),
        );


        if(response.statusCode==201 || response.statusCode==200)
        {
          final token = jsonDecode(response.body)['token'];
          final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
          await secureStorage.write(key: 'token', value: token);
          // Save token securely

          //Now fetch and store geofences securely

          final hasStoredData = await secureStorage.read(key: 'geo_data_written');
          if (hasStoredData == null) {
            final key = Hive.generateSecureKey();
            await secureStorage.write(key: 'hive_key', value: key.join(','));
            final encryptionKey = Uint8List.fromList(key);

            final responses = await http.get(
              Uri.parse('http://$IP/geocoordinates'),
              headers: {"Authorization": "Bearer $token"},
            );

            if (responses.statusCode == 200) {
              final List<dynamic> geofenceData = jsonDecode(responses.body);
              await Hive.openBox('geoBox', encryptionCipher: HiveAesCipher(encryptionKey)); // ensure box open
              await CoordinateStorage().storeCoordinates(geofenceData, encryptionKey);
            }
          }


          if(response.statusCode==201) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Device registered successfully')),
            );
          }
          else
            {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed In Successfully')),
              );
            }
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DashboardScreen(token: token)),
          );
        }

        else if(response.statusCode==401)
          {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Incorrect Password')),
            );
          }

        else if(response.statusCode==400)
          {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid Username')),
            );
          }

        else if(response.statusCode==402)
          {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account already registered in another device')),
            );
          }
        else
          {

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unknown error')),
            );
          }



    } else {
      // Handle validation errors if needed.
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color.fromARGB(255, 79, 108, 147);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presense360'),
        backgroundColor: themeColor,
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Move the logo a bit upward for a better look.
              Transform.translate(
                offset: const Offset(0, -20),
                child: Image.asset(
                  //'images/amrita-vishwa-vidyapeetham-logo-png_seeklogo-519922.png',
                  'images/logo1.png',
                  height: 100,
                ),
              ),
              const SizedBox(height: 40),
              // Login form container with a floating "Login" header.
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 30,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            // Username TextField with theme color for focused border/label.
                            TextFormField(
                              controller: usernameController,
                              decoration: InputDecoration(
                                labelText: 'Username',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: themeColor),
                                ),
                                floatingLabelStyle: const TextStyle(color: themeColor),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your username';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            // Password TextField with theme color for focused border/label.
                            TextFormField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: themeColor),
                                ),
                                floatingLabelStyle: const TextStyle(color: themeColor),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 30),
                            // Sign In Button.
                            ElevatedButton(
                              onPressed: _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // "Login" header overlapping the border.
                    Positioned(
                      top: -15,
                      left: 120,
                      right: 120,
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        color: Colors.white,
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
