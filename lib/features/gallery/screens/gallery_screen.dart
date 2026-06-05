import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/gallery_provider.dart';
import '../models/palette_entry.dart';
import '../../../core/utils/wcag_checker.dart';
import 'wcag_screen.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Library',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF212121))),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Consumer<GalleryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF2196F3)));
          }

          if (provider.entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.palette_outlined,
                      color: Colors.grey.shade300, size: 80),
                  const SizedBox(height: 16),
                  const Text('Belum ada palet tersimpan',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  const Text('Tap tombol Scan untuk mulai',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.entries.length,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
            itemBuilder: (context, index) {
              final entry = provider.entries[index];
              return _PaletteCard(entry: entry);
            },
          );
        },
      ),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  final PaletteEntry entry;
  const _PaletteCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          if (entry.thumbnailPath != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.file(
                File(entry.thumbnailPath!),
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                cacheWidth: 400,
                cacheHeight: 300,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  color: Colors.grey.shade100,
                  child: Icon(Icons.image_outlined,
                      color: Colors.grey.shade300, size: 40),
                ),
              ),
            ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => _editLabel(context),
                  child: Row(
                    children: [
                      Text(
                        entry.objectLabel.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF212121),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit,
                          color: Color(0xFF2196F3), size: 12),
                    ],
                  ),
                ),
                Text(
                  _formatDate(entry.createdAt),
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 11),
                ),
              ],
            ),
          ),

          Divider(color: Colors.grey.shade100, height: 1),

          // Warna
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: entry.colors.map((colorMap) {
                return _ColorRow(colorMap: colorMap);
              }).toList(),
            ),
          ),

          // Tombol bawah
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                // WCAG Check
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WcagScreen(entry: entry),
                    ),
                  ),
                  icon: const Icon(Icons.accessibility_new,
                      color: Color(0xFF2196F3), size: 16),
                  label: const Text('WCAG',
                      style: TextStyle(
                          color: Color(0xFF2196F3), fontSize: 12)),
                ),
                const Spacer(),
                // Hapus
                TextButton.icon(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 16),
                  label: const Text('Hapus',
                      style:
                          TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _editLabel(BuildContext context) {
    final controller =
        TextEditingController(text: entry.objectLabel);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Nama',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Nama objek...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF2196F3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF2196F3)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final newLabel = controller.text.trim();
              if (newLabel.isNotEmpty) {
                context
                    .read<GalleryProvider>()
                    .updateLabel(entry, newLabel);
              }
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Palet?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Data ini akan dihapus dari penyimpanan lokal dan cloud.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () {
              context.read<GalleryProvider>().delete(entry);
              Navigator.pop(context);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final Map<String, dynamic> colorMap;
  const _ColorRow({required this.colorMap});

  @override
  Widget build(BuildContext context) {
    final r = colorMap['r'] as int;
    final g = colorMap['g'] as int;
    final b = colorMap['b'] as int;
    final hex = colorMap['hex'] as String;
    final cmyk =
        Map<String, dynamic>.from(colorMap['cmyk'] as Map);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Color circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.fromRGBO(r, g, b, 1.0),
              border:
                  Border.all(color: Colors.grey.shade200, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(r, g, b, 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Color info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hex,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF212121))),
                Text(
                  'RGB($r, $g, $b)',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 11),
                ),
                Text(
                  'CMYK(${cmyk['c']}, ${cmyk['m']}, ${cmyk['y']}, ${cmyk['k']})',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),

          // Copy button
          _CopyButton(r: r, g: g, b: b, hex: hex, cmyk: cmyk),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final int r, g, b;
  final String hex;
  final Map<String, dynamic> cmyk;

  const _CopyButton({
    required this.r,
    required this.g,
    required this.b,
    required this.hex,
    required this.cmyk,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      icon: Icon(Icons.copy_outlined,
          color: Colors.grey.shade400, size: 18),
      tooltip: 'Copy warna',
      onSelected: (value) {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied: $value'),
            backgroundColor: const Color(0xFF2196F3),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        );
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: hex,
          child: Row(
            children: [
              const Icon(Icons.tag,
                  size: 16, color: Color(0xFF2196F3)),
              const SizedBox(width: 8),
              Text('HEX: $hex',
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'rgb($r, $g, $b)',
          child: Row(
            children: [
              const Icon(Icons.circle,
                  size: 16, color: Color(0xFF2196F3)),
              const SizedBox(width: 8),
              Text('RGB: $r, $g, $b',
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value:
              'cmyk(${cmyk['c']}%, ${cmyk['m']}%, ${cmyk['y']}%, ${cmyk['k']}%)',
          child: Row(
            children: [
              const Icon(Icons.print_outlined,
                  size: 16, color: Color(0xFF2196F3)),
              const SizedBox(width: 8),
              Text(
                  'CMYK: ${cmyk['c']}, ${cmyk['m']}, ${cmyk['y']}, ${cmyk['k']}',
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}