import 'package:flutter/material.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';

class EnrolledUsersPage extends StatefulWidget {
  const EnrolledUsersPage({super.key});

  @override
  State<EnrolledUsersPage> createState() => _EnrolledUsersPageState();
}

class _EnrolledUsersPageState extends State<EnrolledUsersPage> {
  late Future<List<String>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = FaceBiometric.getEnrolledUsers();
  }

  void _refresh() {
    setState(() => _usersFuture = FaceBiometric.getEnrolledUsers());
  }

  Future<void> _deleteUser(String userId) async {
    await FaceBiometric.deleteEnrollment(userId: userId);
    _refresh();
  }

  Future<void> _confirmClearAll() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Clear all enrollments?'),
        content: const Text(
            'This permanently deletes every enrolled face template on this device. This cannot be undone.'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FaceBiometric.clearAllEnrollments();
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enrolled Users'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear All',
            onPressed: _confirmClearAll,
          ),
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: _usersFuture,
        builder: (BuildContext context, AsyncSnapshot<List<String>> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<String> users = snapshot.data!;
          if (users.isEmpty) {
            return const Center(child: Text('No users enrolled yet.'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (BuildContext context, int index) {
              final String userId = users[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(userId),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteUser(userId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
