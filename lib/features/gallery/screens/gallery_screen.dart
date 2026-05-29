import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/gallery_provider.dart';
import '../models/palette_entry.dart';
import 'wcag_screen.dart';
import 'dart:io';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Gallery',
            style: TextStyle(color: Colors.white)),
      ),
      body: Consumer<GalleryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.entries.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.palette_outlined, color: Colors.grey, size: 64),
                  SizedBox(height: 16),
                  Text('Belum ada palet tersimpan',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Tap tombol kamera untuk mulai',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
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

  void _editLabel(BuildContext context) {
    final controller = TextEditingController(text: entry.objectLabel);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Edit Nama',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nama objek...',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final newLabel = controller.text.trim();
              if (newLabel.isNotEmpty) {
                context.read<GalleryProvider>().updateLabel(
                      entry,
                      newLabel,
                    );
              }
              Navigator.pop(context);
            },
            child: const Text('Simpan',
                style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          if (entry.thumbnailPath != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.file(
                File(entry.thumbnailPath!),
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                cacheWidth: 400,
                cacheHeight: 300,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.grey[800],
                    child: const Icon(Icons.broken_image, color: Colors.white38),
                  );
                },
              ),
            ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Label objek
                Row(
                  children: [
                    const Icon(Icons.label_outline,
                        color: Colors.white54, size: 16),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _editLabel(context),
                      child: Row(
                        children: [
                          Text(
                            entry.objectLabel.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, color: Colors.white38, size: 12),
                        ],
                      ),
                    ),
                  ],
                ),
                // Tanggal
                Text(
                  _formatDate(entry.createdAt),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Warna
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: entry.colors.map((colorMap) {
                return _ColorRow(colorMap: colorMap);
              }).toList(),
            ),
          ),

          // Tombol WCAG Check
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WcagScreen(entry: entry),
                  ),
                ),
                icon: const Icon(Icons.accessibility_new,
                    color: Colors.blue, size: 16),
                label: const Text('WCAG Check',
                    style: TextStyle(color: Colors.blue, fontSize: 12)),
              ),
            ),
          ),

          // Tombol hapus
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 16),
                label: const Text('Hapus',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Hapus Palet?',
            style: TextStyle(color: Colors.white)),
        content: const Text('Data ini akan dihapus dari Hive dan MongoDB.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              context.read<GalleryProvider>().delete(entry);
              Navigator.pop(context);
            },
            child: const Text('Hapus',
                style: TextStyle(color: Colors.red)),
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
    final cmyk = Map<String, dynamic>.from(colorMap['cmyk'] as Map);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Color circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.fromRGBO(r, g, b, 1.0),
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
          ),
          const SizedBox(width: 12),

          // Color values
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hex,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text(
                  'RGB($r, $g, $b)  •  CMYK(${cmyk['c']}, ${cmyk['m']}, ${cmyk['y']}, ${cmyk['k']})',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),

          // Tombol copy
          _CopyButton(
            colorMap: colorMap,
            r: r, g: g, b: b,
            hex: hex,
            cmyk: cmyk,
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final Map<String, dynamic> colorMap;
  final int r, g, b;
  final String hex;
  final Map<String, dynamic> cmyk;

  const _CopyButton({
    required this.colorMap,
    required this.r,
    required this.g,
    required this.b,
    required this.hex,
    required this.cmyk,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: Colors.grey[850],
      icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
      tooltip: 'Copy warna',
      onSelected: (value) => _copyToClipboard(context, value),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: hex,
          child: Text('Copy HEX: $hex',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
        PopupMenuItem(
          value: 'rgb($r, $g, $b)',
          child: Text('Copy RGB: rgb($r, $g, $b)',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
        PopupMenuItem(
          value: 'cmyk(${cmyk['c']}%, ${cmyk['m']}%, ${cmyk['y']}%, ${cmyk['k']}%)',
          child: Text(
              'Copy CMYK: ${cmyk['c']}, ${cmyk['m']}, ${cmyk['y']}, ${cmyk['k']}',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ],
    );
  }

  void _copyToClipboard(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $value'),
        backgroundColor: Colors.grey[800],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}