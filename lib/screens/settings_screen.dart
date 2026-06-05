import 'package:flutter/material.dart';
import '../config/env_config.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: 'Model AI'),
          _SettingsTile(
            icon: Icons.model_training,
            label: 'Model',
            value: EnvConfig.modelPath.split('/').last,
          ),
          _SettingsTile(
            icon: Icons.tune,
            label: 'Confidence Threshold',
            value: EnvConfig.confidenceThreshold.toString(),
          ),
          _SettingsTile(
            icon: Icons.input,
            label: 'Input Size',
            value: '${EnvConfig.inputSize}×${EnvConfig.inputSize}',
          ),

          const SizedBox(height: 16),
          _SectionHeader(title: 'Ekstraksi Warna'),
          _SettingsTile(
            icon: Icons.palette,
            label: 'Jumlah Warna (K)',
            value: EnvConfig.kValue.toString(),
          ),
          _SettingsTile(
            icon: Icons.save,
            label: 'Maks Palet Tersimpan',
            value: EnvConfig.maxSavedPalettes.toString(),
          ),

          const SizedBox(height: 16),
          _SectionHeader(title: 'Tentang'),
          _SettingsTile(
            icon: Icons.info_outline,
            label: 'Versi Aplikasi',
            value: '1.0.0',
          ),
          _SettingsTile(
            icon: Icons.school_outlined,
            label: 'Dibuat untuk',
            value: 'Tugas Besar Pengolahan Citra Digital',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF2196F3),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SettingsTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2196F3), size: 20),
        title: Text(label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF212121))),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ),
    );
  }
}