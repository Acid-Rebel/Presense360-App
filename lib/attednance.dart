import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'login.dart';
import 'dash.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'leave.dart';

class AttendanceScreen extends StatefulWidget
{
  final String token;
  const AttendanceScreen({required this.token});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String get token => widget.token;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTimeRange? _selectedDateRange;
  String _filter = 'All';
  //final IP ="192.168.1.2:5000";
  //final String IP="10.12.66.36:5000";
  final String IP="10.12.225.247:5000";


  final Color themeColor = const Color.fromARGB(255, 151, 10, 0);

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

  //getting attendance data from server
  Future<List<Map<String, dynamic>>> fetchData() async {
    //final url = 'http://10.0.2.2:5000/attendance?rollno=$usernamee';
    // final url = 'http://10.12.178.137:5000/attendance?rollno=$usernamee';
    // final url = 'http://192.168.1.2:5000/attendance?rollno=$usernamee';
    final url = Uri.parse('http://$IP/attendance');
    try {
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);
        if (jsonData is List) {
          return List<Map<String, dynamic>>.from(jsonData);
        } else {
          print("Unexpected JSON format: $jsonData");
          return [];
        }
      }
      else if (response.statusCode == 500)
        {
          showSimplePopupsign(context, "Internal Server Error");
          return [];
        }
      else if (response.statusCode == 406)
      {
        showSimplePopupsign(context, "Invalid Token, re-login!");
        return [];
      }
      else {
        print('Failed to fetch attendance data: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching attendance data: $e');
      return [];
    }
  }


  late Future<List<Map<String, dynamic>>> attendanceData;

  @override
  void initState() {
    super.initState();
    attendanceData = fetchData();
    attendanceData.then((data) {
      for (var item in data) {
        print("Received date from API: ${item['currdate']}");
      }
    });
  }


  // Map<String, String>? getAttendanceData(DateTime date) {
  //   return attendanceData[DateTime(date.year, date.month, date.day)];
  // }

  String _mapStatus(int? code) {
    switch (code) {
      case 0:
        return "Checked In";
      case 1:
        return "Casual Leave";
      case 2:
        return "Medical Leave";
      case 3:
        return "Public Holiday";
      case 4:
        return "Absent";
      case 5:
        return "Not checked in";
      default:
        return "Unknown"; // Ensure it always returns a valid String
    }
  }





  Future<Map<String, dynamic>> getAttendanceData(DateTime date) async {
    List<Map<String, dynamic>> data = await attendanceData; // Await the fetched data

    // Format date as "YYYY-MM-DD" to match the database format
    String formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // Ensure comparison matches correctly
    Map<String, dynamic>? entry = data.firstWhere(
          (item) => item['currdate'].split('T')[0] == formattedDate,
      orElse: () => {},
    );

    if (entry.isEmpty) {
      print("No data found for date: $formattedDate");
      return {};
    }

    return {
      "status": _mapStatus(entry['type']),
      "checkIn": entry['checkin'] ?? "N/A",
      "checkOut": entry['checkout'] ?? "N/A",
    };
  }


  Future<List<Map<String, dynamic>>> getFilteredAttendance() async {
    List<Map<String, dynamic>> data = await attendanceData;

    return data.where((entry) {
      DateTime entryDate = DateTime.parse(entry['currdate']);

      // Ensure the entry belongs to the currently focused month and year
      bool isSameMonth = entryDate.year == _focusedDay.year && entryDate.month == _focusedDay.month;

      // Map the leave type properly
      String status = _mapStatus(entry['type']) ?? "Unknown";

      // Ensure filtering works correctly
      bool matchesFilter = _filter == 'All' || status == _filter;
      bool isWithinRange = _selectedDateRange == null ||
          (entryDate.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
              entryDate.isBefore(_selectedDateRange!.end.add(const Duration(days: 1))));

      return isSameMonth && matchesFilter && isWithinRange && status != "Unknown";
    }).map((entry) {
      return {
        "date": DateTime.parse(entry['currdate']),
        "status": _mapStatus(entry['type']), // Ensure it maps correctly
        "checkIn": entry["checkin"] ?? "N/A",
        "checkOut": entry["checkout"] ?? "N/A",
      };
    }).toList();
  }










  void _showAttendancePopup(DateTime date, Future<Map<String, dynamic>> futureData) {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: futureData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                title: Text("Attendance Details"),
                content: SizedBox(
                  height: 50,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty || snapshot.data!["status"] == "Unknown") {
              return const AlertDialog(
                title: Text("Attendance Details"),
                content: Text("No Data Available"),
              );
            }

            Map<String, dynamic> attendanceEntry = snapshot.data!;

            return AlertDialog(
              title: const Text("Attendance Details"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Date: ${date.day}/${date.month}/${date.year}"),
                  Text("Status: ${attendanceEntry["status"]}"),
                  Text("Check In: ${attendanceEntry["checkIn"] ?? "N/A"}"),
                  Text("Check Out: ${attendanceEntry["checkOut"] ?? "N/A"}"),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
    );
  }







  /// Builds a default grey-colored container when no data is available.
  Widget _buildDefaultContainer(DateTime day, Color color) {
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Text(day.day.toString())),
    );
  }

  /// Builds a loading indicator when data is being fetched.
  Widget _buildLoadingContainer(DateTime day) {
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  /// Builds a container based on attendance status.
  Widget _buildStatusContainer(DateTime day, String? status) {
    Color statusColor = _getStatusColor(status);
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Text(day.day.toString())),
    );
  }

  /// Maps the status to its corresponding color.
  Color _getStatusColor(String? status) {
    switch (status) {
      case "Absent":
        return Colors.red[300]!;
      case "Medical Leave":
        return Colors.orange[300]!;
      case "Casual Leave":
        return Colors.yellow[300]!;
      case "Public Holiday":
        return Colors.blue[300]!; // Set a color for Public Holiday
      case "Not checked in":
        return Colors.brown;
      default:
        return Colors.green[300]!; // Default for Checked In
    }
  }






  @override
  Widget build(BuildContext context) {
    Future<List<Map<String, dynamic>>> filteredAttendance = getFilteredAttendance();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: themeColor,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("AmritaAttend - Faculty"),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: () async {
                final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
                await secureStorage.delete(key: 'token');
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
          Expanded(
            child: Column(
              children: [
                // Calendar widget.
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    final data = getAttendanceData(selectedDay);
                    _showAttendancePopup(selectedDay, data);
                  },
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
                    leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.black),
                    rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.black),
                    headerMargin: const EdgeInsets.symmetric(vertical: 8),
                    titleCentered: false,
                  ),
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                      _selectedDateRange = null;
                    });
                  },

                  onHeaderTapped: (focusedDay) async {
                    final int? pickedYear = await showYearPicker(
                      context: context,
                      initialDate: focusedDay,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (pickedYear != null) {
                      setState(() {
                        _focusedDay = DateTime(pickedYear, focusedDay.month, focusedDay.day);
                        _selectedDateRange = null;
                        ///attendanceData = generateMonthlyData(_focusedDay);
                      });
                    }
                  },
                  calendarBuilders: CalendarBuilders(
                    todayBuilder: (context, day, focusedDay) {
                      return FutureBuilder<Map<String, dynamic>>(
                        future: getAttendanceData(day),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return _buildLoadingContainer(day);
                          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty || snapshot.data!["status"] == "Unknown") {
                            return _buildDefaultContainer(day, Colors.transparent); // No highlight
                          } else {
                            return _buildStatusContainer(day, snapshot.data!['status']);
                          }
                        },
                      );
                    },
                    defaultBuilder: (context, day, focusedDay) {
                      return FutureBuilder<Map<String, dynamic>>(
                        future: getAttendanceData(day),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return _buildLoadingContainer(day);
                          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty || snapshot.data!["status"] == "Unknown") {
                            return _buildDefaultContainer(day, Colors.transparent); // No highlight
                          } else {
                            return _buildStatusContainer(day, snapshot.data!['status']);
                          }
                        },
                      );
                    },
                  ),

                ),
                // Filter & Date Range picker controls.
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: DropdownButton<String>(
                        value: _filter,
                        onChanged: (String? newValue) {
                          setState(() {
                            _filter = newValue!;
                          });
                        },
                        items: <String>['All', 'Checked In', 'Absent', 'Medical Leave', 'Casual Leave', 'Public Holiday']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),

                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        onPressed: () async {
                          final DateTimeRange? pickedRange = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(_focusedDay.year, _focusedDay.month, 1),
                            lastDate: DateTime(_focusedDay.year, _focusedDay.month + 1, 0),
                            initialDateRange: _selectedDateRange,
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.light().copyWith(
                                  primaryColor: themeColor,
                                  buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (pickedRange != null) {
                            setState(() {
                              _selectedDateRange = pickedRange;
                              _focusedDay = pickedRange.start;
                            });
                          }
                        },
                        child: const Text("Select Date Range"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Monthly attendance data list.
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: getFilteredAttendance(), // Fetch filtered data dynamically
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return const Center(child: Text("Failed to load attendance data"));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text("No attendance data available for this month"));
                      }

                      List<Map<String, dynamic>> fetchedData = snapshot.data!;

                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            for (var data in fetchedData)
                              GestureDetector(
                                onTap: () async {
                                  DateTime selectedDate = data["date"]; // Ensure it's a DateTime object

                                  Map<String, dynamic> fullData = await getAttendanceData(selectedDate) ?? {};

                                  if (fullData.isEmpty || fullData["status"] == "Unknown") {
                                    debugPrint("No valid data for selected tile: $selectedDate");
                                    return; // Prevent showing a popup if the data is invalid
                                  }

                                  _showAttendancePopup(selectedDate, Future.value(fullData));
                                },



                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(data["status"]),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${data["date"].day}/${data["date"].month}/${data["date"].year}",
                                        style: const TextStyle(color: Colors.white, fontSize: 16),
                                      ),
                                      Text(
                                        data["status"], // Show status text
                                        style: const TextStyle(color: Colors.white, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),



              ],
            ),
          ),
        ],
      ),
      // Bottom Navigation Bar.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // Attendance is active.
        onTap: (int index) {
          if (index == 0) {

            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DashboardScreen(token: token)),
            );
          } else if (index == 1) {
            // Already on Attendance.
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

  // Color _getStatusColor(String? status) {
  //   switch (status) {
  //     case "Absent":
  //       return Colors.red[300]!;
  //     case "Medical Leave":
  //       return Colors.orange[300]!;
  //     case "Casual Leave":
  //       return Colors.yellow[300]!;
  //     default:
  //       return Colors.green[300]!;
  //   }
  // }
}

Future<int?> showYearPicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  final int firstYear = firstDate.year;
  final int lastYear = lastDate.year;

  int? pickedYear = await showDialog<int>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Select Year'),
        content: SingleChildScrollView(
          child: ListBody(
            children: List.generate(lastYear - firstYear + 1, (index) {
              final year = firstYear + index;
              return ListTile(
                title: Text('$year'),
                onTap: () {
                  Navigator.pop(context, year);
                },
              );
            }),
          ),
        ),
      );
    },
  );

  return pickedYear;
}
