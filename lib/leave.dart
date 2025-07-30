import 'package:flutter/material.dart';
import 'dash.dart';
import 'attednance.dart';
import 'login.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

class LeaveRequestPage extends StatefulWidget {
  final String token;
  const LeaveRequestPage({required this.token});

  @override
  State<LeaveRequestPage> createState() => _LeaveRequestPageState();
}

class _LeaveRequestPageState extends State<LeaveRequestPage> {
  String get token => widget.token;
  final List<Map<String, dynamic>> _leaveRequests = [];
  String _selectedType = "All";
  String _selectedStatus = "All";
  DateTimeRange? _selectedDateRange;
  DateTimeRange? _selectedDateRangeCreate;
  final String IP="10.12.225.247:5000";
  @override
  void initState() {
    super.initState();
    _fetchLeaveRequests();
  }

  void _fetchLeaveRequests() {
    // Simulating fetching data from an API or backend
    setState(() {
      _leaveRequests.addAll([
        {
          "from": "2025-01-12",
          "to": "2025-01-13",
          "type": "Casual",
          "status": "Not Approved",
          "reason": "Personal work",
          "rejectionReason": "Insufficient leave balance"
        },
        {
          "from": "2025-01-13",
          "to": "2025-01-15",
          "type": "Medical",
          "status": "Approved",
          "reason": "Health issues"
        },
        {
          "from": "2025-01-14",
          "to": "2025-01-14",
          "type": "Casual",
          "status": "Pending",
          "reason": "Family function"
        },
        {
          "from": "2025-01-15",
          "to": "2025-01-16",
          "type": "Medical",
          "status": "Not Approved",
          "reason": "Doctor appointment",
          "rejectionReason": "Documents missing"
        },
        {
          "from": "2025-01-16",
          "to": "2025-01-18",
          "type": "Casual",
          "status": "Approved",
          "reason": "Vacation trip"
        },
      ]);
    });
  }

  void _resetDateRange() {
    setState(() {
      _selectedDateRange = null;
    });
  }

  void _createLeaveRequest() {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String? type;
    String reason = "";
    bool showDateRangeError = false; // Track if date range error should be shown

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Create New Leave Request"),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Type"),
                    items: ["Medical", "Casual"]
                        .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        type = value;
                      });
                    },
                    validator: (value) =>
                    value == null ? "Please select a leave type" : null,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Reason"),
                    maxLines: 3,
                    onChanged: (value) {
                      reason = value;
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? "Please provide a reason for the leave"
                        : null,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final dateRange = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (dateRange != null) {
                        setDialogState(() {
                          _selectedDateRangeCreate = dateRange;
                          showDateRangeError = false; // Reset the error
                        });
                      }
                    },
                    child: Text(
                      _selectedDateRangeCreate == null
                          ? "Select Date Range"
                          : "${_selectedDateRangeCreate!.start.toLocal().toIso8601String().split('T').first} to ${_selectedDateRangeCreate!.end.toLocal().toIso8601String().split('T').first}",
                    ),
                  ),
                  if (showDateRangeError)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Date range is required",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  if (_selectedDateRangeCreate == null) {
                    setDialogState(() {
                      showDateRangeError = true; // Show the error
                    });
                    return;
                  }

                  // Add the leave request
                  setState(() {
                    _leaveRequests.add({
                      "from": _selectedDateRangeCreate!.start
                          .toIso8601String()
                          .split('T')
                          .first,
                      "to": _selectedDateRangeCreate!.end
                          .toIso8601String()
                          .split('T')
                          .first,
                      "type": type,
                      "status": "Pending",
                      "reason": reason,
                    });
                    _selectedDateRangeCreate = null; // Reset the date range
                  });

                  // Close the dialog after updating the UI
                  Navigator.pop(context);
                }
              },
              child: const Text("Apply"),
            ),
          ],
        ),
      ),
    );
  }



  void _showLeaveDetails(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Leave Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("From: ${request["from"]}"),
            Text("To: ${request["to"]}"),
            Text("Type: ${request["type"]}"),
            Text("Reason: ${request["reason"]}"),
            if (request["status"] == "Not Approved" && request.containsKey("rejectionReason"))
              Text("Rejection Reason: ${request["rejectionReason"]}", style: const TextStyle(color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRequests = _leaveRequests.where((request) {
      if (_selectedType != "All" && request["type"] != _selectedType) {
        return false;
      }
      if (_selectedStatus != "All" && request["status"] != _selectedStatus) {
        return false;
      }
      if (_selectedDateRange != null) {
        final requestStartDate = DateTime.parse(request["from"]);
        final requestEndDate = DateTime.parse(request["to"]);
        if (requestStartDate.isAfter(_selectedDateRange!.end) ||
            requestEndDate.isBefore(_selectedDateRange!.start)) {
          return false;
        }
      }
      return true;
    }).toList();

    final Color themeColor = Color.fromARGB(255, 79, 108, 147);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: themeColor,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Presense360"),
            Row(
              children: [
                // Logout Icon
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
          ],
        ),
      ),
      body: Column(
        children: [
          // Navigation Tabs
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _selectedType,
                  items: ["All", "Medical", "Casual"]
                      .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedStatus,
                  items: ["All", "Approved", "Pending", "Not Approved"]
                      .map((status) => DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                  },
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    final dateRange = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (dateRange != null) {
                      setState(() {
                        _selectedDateRange = dateRange;
                      });
                    }
                  },
                  child: const Text("Date"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _resetDateRange,
                  child: const Text("Reset Date"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: filteredRequests.length,
              itemBuilder: (context, index) {
                final request = filteredRequests[index];
                final statusColor = request["status"] == "Approved"
                    ? Colors.green[300]
                    : request["status"] == "Pending"
                    ? Colors.orange[300]
                    : Colors.red[300];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: GestureDetector(
                    onTap: () => _showLeaveDetails(request),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "From: ${request["from"]}  To: ${request["to"]}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${request["type"]} Leave",
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            request["status"],
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2, // Attendance is active.
        onTap: (int index) {
          if (index == 0) {

            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DashboardScreen(token: token)),
            );
          } else if (index == 1) {
            // Already on Attendance.
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AttendanceScreen(token: token)),
            );
          } else if (index == 2) {
            // Navigator.pushAndRemoveUntil(
            //   context,
            //   MaterialPageRoute(builder: (context) => LeaveRequestPage(token: token)),
            //       (Route<dynamic> route) => false,
            //);
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
      floatingActionButton: FloatingActionButton(
        onPressed: _createLeaveRequest,
        child: const Icon(Icons.add),
      ),
    );
  }
}

