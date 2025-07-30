import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:safe_device/safe_device.dart';
import 'login.dart';
import 'package:http/http.dart' as http;
import 'attednance.dart';
import 'leave.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:camera/camera.dart';
import 'geofence_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'geofence_utils.dart';
import 'package:hive/hive.dart';






class DashboardScreen extends StatefulWidget {
  //final String username;
  final String token;
  const DashboardScreen({required this.token});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Placeholder functions for user details.


  String get token=>widget.token;
  //String get usernamee => widget.username;

  //late Future<List<String?>> data;
  Map<String, dynamic> datas = {};
  String status = "Not Checked In";
  String? checkInTime = "";
  String? checkOutTime = "";
  bool logindontappear = true;
  bool serverError=false;
  //final String IP="192.168.1.2:5000";
  //final String IP="10.12.66.36:5000";
  final String IP="10.12.225.247:5000";


  @override
  void initState() {
    super.initState();
    processData();
    setTime();
  }



  void showCheckDialog(bool isCheckIn) async {
    String locationStatus = "Acquiring GPS...";
    String biometricStatus = "Awaiting...";
    String? success;

    late StateSetter dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            dialogSetState = setState;
            return AlertDialog(
              title: Text(isCheckIn ? 'Check In' : 'Check Out'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Location: $locationStatus"),
                  const SizedBox(height: 10),
                  Text("Biometric: $biometricStatus"),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );

    // LOCATION CHECK
    int stat = await isInLocation();
    if (stat == -4)
      {
        showSimplePopupsign(context, "Invalid Token, re login!");
      }
    dialogSetState(() {
      locationStatus = switch (stat) {
        1 => "✅ In premise",
        0 => "❌ Not in premise",
        -4 => "❌ Invalid Token",
        -99=>"️⚠️GPS MOCKED!!",
        _ => "⚠️ GPS/Permission error"
      };
    });

    // BIOMETRIC (FACIAL) CHECK USING WEBSOCKET

          // Show final result
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("Result"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Location: $locationStatus"),
                    Text("Biometric: Feature to be implemented soon"),
                    const SizedBox(height: 10),
                    if (stat == 1 )
                      Text(
                        isCheckIn ? "Authenticated  Successfully, Checking in.." : "Authenticated Successfully, Checking out..",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    child: const Text("OK"),
                    onPressed: () {
                       success=="Invalid token"? Navigator.pushAndRemoveUntil(
                         context,
                         MaterialPageRoute(builder: (context) => const LoginScreen()),
                             (Route<dynamic> route) => false,
                       ) // go to login page
                            :Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );

          // Final Action
          if (stat == 1) {
            isCheckIn ? checkin("aa") : checkout("aa");
            setTime();
          }





  }






  void handleCheckIn() => showCheckDialog(true);

  void handleCheckOut() => showCheckDialog(false);

  final LocalAuthentication auth = LocalAuthentication();



  void checkin(String authToken) async
  {

    final url = Uri.parse('http://$IP/dashboard/status/checkin');
    final response = await http.post(
      url,
      headers: {"Authorization": "Bearer $token",'authToken': authToken,},

    );
    if (response.statusCode == 500)
    {
      showSimplePopupsign(context,"Internal Server Error");
      return;
    }
    else if(response.statusCode == 407 || response.statusCode == 408)
      {
        showSimplePopup(context, "Invalid authentication Token, try again");
        return;
      }
    else if(response.statusCode == 405)
    {
      showSimplePopup(context, "Illegal authentication Token, try again");
      return;
    }
    else if(response.statusCode == 406)
      {
        showSimplePopupsign(context, "Invalid Token, re-login!");
        setState(() {
          serverError=true;
        });
        return;
      }
    else if(response.statusCode == 409)
    {
      showSimplePopupsign(context, "Invalid Authentication Token, Try again!");
      setState(() {
      });
      return;
    }
    else if (response.statusCode == 400)
    {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already checked In!')),
      );
    }
    setTime();
  }

  void checkout(String authToken) async
  {

    final url = Uri.parse('http://$IP/dashboard/status/checkout');
    final response = await http.post(
      url,
      headers: {"Authorization": "Bearer $token",'authToken': authToken,},

    );
    if (response.statusCode == 500) {
      showSimplePopupsign(context,"Internal Server Error");
      return;
    }
    else if (response.statusCode == 401) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not Checked In!!')),
      );
      return;
    }
    else if(response.statusCode == 405)
    {
      showSimplePopup(context, "Illegal authentication Token, try again");
      return;
    }
    else if(response.statusCode == 407 || response.statusCode == 407)
    {
      showSimplePopupsign(context, "Invalid Authentication Token, Try again!");
      setState(() {
      });
      return;
    }
    else if (response.statusCode == 402) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already Checked Out')),
      );
      return;
    }
    else if(response.statusCode == 406)
    {
      showSimplePopupsign(context, "Invalid Token, re-login!");
      setState(() {
        serverError=true;
      });
      return;
    }
    setTime();
  }

  void processData() async {
    Map<String, dynamic> fetchedData = await fetchData();
    setState(() {
      datas = fetchedData;
    });
    print("Data fetched:");
    print(datas);
  }

  void showSimplePopup(BuildContext context, String message) {
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
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
              child: Text("Close"),
            ),
          ],
        );
      },
    );
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
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (Route<dynamic> route) => false,
                ); // go to login page
              },
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }
  Future<Map<String, dynamic>> fetchData() async
  {

    final url = Uri.parse('http://$IP/dashboard');
    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );
    if(response.statusCode==500)
      {
        showSimplePopupsign(context, "Internal Server Error");
        setState(() {
          serverError=true;
        });
      }
    else if(response.statusCode==404)
    {
      showSimplePopupsign(context, "User Data not found");
      setState(() {
        serverError=true;
      });
    }
    else if(response.statusCode==406)
    {
      showSimplePopupsign(context, "Invalid token, re-login!");
      setState(() {
        serverError=true;
      });
    }
    return jsonDecode(response.body);
  }

  String? fetchName()
  {
    if (datas["name"]==null)
    {
      return " ";
    }
    return datas["name"];
  }

  String? fetchID()
  {
  if (datas["rollno"]==null)
  {
  return " ";
  }
  return datas["rollno"];
  }

  String? fetchDepartment()
  {
  if (datas["dept"]==null)
  {
  return " ";
  }
  return datas["dept"];
  }

  String? fetchEmail()
  {
  if (datas["email"]==null)
  {
  return " ";
  }
  return datas["email"];
  }

  String? fetchMobile()
  {
  if (datas["mobile"]==null)
  {
  return " ";
  }
  return datas["mobile"];
  }

  String fetchGraceTime() => "160";

  String fetchPhotoUrl() => "https://via.placeholder.com/150";

  String fetchQrCodeUrl() => "https://via.placeholder.com/150";


  String _location = "";

  Future<String> _getPermision() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location service is enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return "GPSENABLE";
    }

    bool isMock = await SafeDevice.isMockLocation;
    if(isMock)
      {
        return "GPSMOCKED";
      }
    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return "PERMISSIONDENIED";
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return "PERMISSIONDENIEDFOREVER";
    }

    return "true";
  }

  void showSimplePopupexit(BuildContext context, String message) {
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

Future<int> isInLocation() async
  {
    String permission = await _getPermision();
    if (permission=="true")
      {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        bool res = await isInsideAnyFence(position.longitude, position.latitude);
        if(res==true)
          {
            return 1;
          }
        else
          {
            return 0;
          }
      }
    else if(permission=="GPSMOCKED")
      {
        showSimplePopupexit(context, "GPS MOCKED!!");
        return -99;
      }
    else
      {
        return -1;
      }
  }



  Future<Map<String, dynamic>> stat() async
  {

    final url = Uri.parse('http://$IP/dashboard/status/stat');
    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );
    if(response.statusCode==500)
      {
        showSimplePopupsign(context, "Internal Server Error");
        setState(() {
          serverError=true;
        });
        return {"message":"Error"};
      }
    else if(response.statusCode==406)
      {
        showSimplePopupsign(context, "Invalid toke, re-login!");
        setState(() {
          serverError=true;
        });
        return {"message":"Error"};
      }
    else if (response.statusCode==201)
    {
      return {};
    }
    else
    {
      return jsonDecode(response.body);
    }
  }

  void setTime() async {
    Map<String, dynamic> latestData = await stat();
    setState(() {
      if (latestData.isEmpty) {
        status = "Not Checked In";
        logindontappear = false;
      }
      else if(latestData["message"]=="Error")
        {
          logindontappear = true;
        }
      else if (latestData["type"] == 0 && latestData["checkout"] == null &&
          latestData["checkin"] != null) {
        status = "Checked In";
        checkInTime = latestData["checkin"];
        logindontappear = false;
      }
      else if (latestData["type"] == 5) {
        status = "Not Checked In";
        logindontappear = false;
      }
      else if (latestData["type"] == 0 && latestData["checkout"] != null &&
          latestData["checkin"] != null) {
        status = "Checked Out";
        checkInTime = latestData["checkin"];
        checkOutTime = latestData["checkout"];
        logindontappear = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color themeColor = Color.fromARGB(255, 79, 108, 147);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: themeColor,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Presense360"),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: () async {
                final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
                await secureStorage.delete(key: 'token');
                await Hive.deleteBoxFromDisk('geoBox');
                await secureStorage.delete(key: 'hive_key');
                await secureStorage.delete(key: 'geo_data_written');
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (Route<dynamic> route) => false,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out Successfully!')),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile pictures row.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ProfileBox(imageUrl: fetchPhotoUrl(), label: "Photo"),
                        ProfileBox(
                            imageUrl: fetchQrCodeUrl(), label: "QR Code"),
                      ],
                    ),
                    const SizedBox(height: 30),
                    InfoText(label: "Name", value: "${fetchName()}"),
                    InfoText(label: "ID", value: "${fetchID()}"),
                    InfoText(
                        label: "Department", value: "${fetchDepartment()}"),
                    //InfoText(label: "Amrita Email", value: "${fetchEmail()}"),
                    InfoText(label: "Mobile", value: "${fetchMobile()}"),
                    InfoText(label: "Status", value: "${status}"),
                    InfoText(label: "Check In",
                        value: checkInTime ?? "Not Checked In"),
                    InfoText(label: "Check Out",
                        value: checkOutTime ?? "Not Checked Out"),
                    InfoText(label: "Grace Time Available",
                        value: "${fetchGraceTime()} / 180"),
                    const SizedBox(height: 20),
                    Center(
                      child:
                          (serverError==true)
                          ?const SizedBox()
                          :(logindontappear == true)
                          ? const SizedBox()
                          : checkInTime == ""
                          ? CheckButton(
                          label: "Check In", onPressed: handleCheckIn)
                          : (checkOutTime == ""
                          ? CheckButton(
                          label: "Check Out", onPressed: handleCheckOut)
                          : const SizedBox()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Professional Bottom Navigation Bar.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        // Dashboard is active.
        onTap: (int index) {
          if (index == 0) {
            // Already on Dashboard.
          } else if (index == 1) {
            String user = "${fetchID()}";
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AttendanceScreen(token: token)),
            );
          } else if (index == 2) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => LeaveRequestPage(token: token)),
              (Route<dynamic> route) => false,
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note),
            label: "Attendance",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.request_page),
            label: "Leave Request",
          ),
        ],
        selectedItemColor: themeColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }


}
class ProfileBox extends StatelessWidget {
  final String imageUrl;
  final String label;

  const ProfileBox({super.key, required this.imageUrl, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: 150,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Center(child: Text(label));
        },
      ),
    );
  }
}

class InfoText extends StatelessWidget {
  final String label;
  final String value;

  const InfoText({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        "$label: $value",
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}

class CheckButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const CheckButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 79, 108, 147),
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}