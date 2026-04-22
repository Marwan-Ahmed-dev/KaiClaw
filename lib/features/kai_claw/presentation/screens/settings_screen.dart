import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaiclaw/core/constants/app_constants.dart';
import 'package:url_launcher/url_launcher.dart'; // Need to add to pubspec.yaml

// NOTE: url_launcher is required for this screen.
// Add to pubspec.yaml under dependencies:
// url_launcher: ^6.2.5

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section for Webhook Configuration
          Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Webhook Configuration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text('Current Webhook URL: ${AppConstants.webhookUrl}'),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.link),
                    label: const Text('Open Webhook URL'),
                    onPressed: () async {
                      final url = Uri.parse(AppConstants.webhookUrl);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {
                        // Handle error, e.g., show a snackbar
                        if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not launch ${AppConstants.webhookUrl}')),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text('Note: To change the webhook URL, you need to edit the app_constants.dart file directly and rebuild the application.'),
                ],
              ),
            ),
          ),

          // Placeholder for other settings
          Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'General Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Enable Dark Mode (Coming Soon)'),
                    value: false, // Placeholder for actual state
                    onChanged: (bool value) {
                      // TODO: Implement dark mode toggle
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Dark mode feature is not yet implemented.')),
                        );
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('About KaiClaw'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'KaiClaw Control',
                        applicationVersion: '1.0.0',
                        applicationLegalese: '© 2024 KaiClaw Team',
                        children: [
                          const Text('This application allows you to control the Kaiowa AI assistant via webhooks.'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
