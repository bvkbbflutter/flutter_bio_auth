import 'package:flutter/material.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';

class DeliveryCompliancePage extends StatefulWidget {
  const DeliveryCompliancePage({super.key});

  @override
  State<DeliveryCompliancePage> createState() => _DeliveryCompliancePageState();
}

class _DeliveryCompliancePageState extends State<DeliveryCompliancePage> {
  UniformPreset _selectedPreset = UniformPreset.zeptoPurple;
  bool _requireHelmet = true;
  bool _requireMotorcycle = true;
  bool _requireFace = true;
  bool _requireMask = false;

  void _startInspection() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DeliveryComplianceView(
          options: ComplianceOptions(
            targetUniform: _selectedPreset,
            requireHelmet: _requireHelmet,
            requireMotorcycle: _requireMotorcycle,
            requireFaceVerification: _requireFace,
            requireMask: _requireMask,
          ),
          onComplete: (result) {
            Navigator.of(context).pop();
            _showResultDialog(result);
          },
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _showResultDialog(DeliveryComplianceResult result) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Icon(
            result.isReady ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 48,
            color: result.isReady ? const Color(0xFF00E676) : Colors.orange,
          ),
          title: Text(
            result.isReady
                ? 'Shift Check-In Approved!'
                : 'Inspection Incomplete',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  result.statusMessage,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (result.detectedUniformColor != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: result.detectedUniformColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Observed Shirt: ${UniformPresetExtension.describeColor(result.detectedUniformColor!)} (${UniformPresetExtension.colorToHex(result.detectedUniformColor!)})',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 24),
                ...result.checks.map((chk) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          chk.passed ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: chk.passed
                              ? const Color(0xFF00E676)
                              : Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                chk.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                chk.reason,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: chk.passed
                                      ? Colors.grey.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Partner Compliance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          // Hero Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  _selectedPreset.primaryColor,
                  _selectedPreset.primaryColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _selectedPreset.primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.two_wheeler, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Rider Onboarding & Shift Check-In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Inspired by Zepto, Swiggy, and Zomato safety pipelines. Inspects your live face match, helmet, mask, and company uniform.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Selected Brand: ${_selectedPreset.displayName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Brand Uniform Selector
          Text(
            'Target Delivery Brand Uniform',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: UniformPreset.values.map((preset) {
              final bool isSelected = _selectedPreset == preset;
              return ChoiceChip(
                label: Text(preset.displayName),
                selected: isSelected,
                selectedColor: preset.primaryColor.withOpacity(0.2),
                avatar: CircleAvatar(
                  backgroundColor: preset.primaryColor,
                  radius: 8,
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedPreset = preset);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Compliance Switches
          Text(
            'Safety & Verification Gates',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Require Motorcycle Helmet'),
            subtitle: const Text('Upper head & chin-strap detection'),
            value: _requireHelmet,
            onChanged: (val) => setState(() => _requireHelmet = val),
          ),
          SwitchListTile(
            title: const Text('Require Motorcycle / Two-Wheeler Context'),
            subtitle:
                const Text('Rider vehicle presence and posture validation'),
            value: _requireMotorcycle,
            onChanged: (val) => setState(() => _requireMotorcycle = val),
          ),
          SwitchListTile(
            title: const Text('Require 1:1 Face Verification'),
            subtitle: const Text('Matches against registered partner profile'),
            value: _requireFace,
            onChanged: (val) => setState(() => _requireFace = val),
          ),
          SwitchListTile(
            title: const Text('Mandate Face Mask'),
            subtitle: const Text('Turn on for pandemic / pollution guidelines'),
            value: _requireMask,
            onChanged: (val) => setState(() => _requireMask = val),
          ),
          const SizedBox(height: 32),

          // Start Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: _selectedPreset.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.camera_alt),
            label: const Text(
              'Launch Live Check-In Scanner',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: _startInspection,
          ),
        ],
      ),
    );
  }
}
