import 'package:flutter/material.dart';
import '../models/palette_entry.dart';
import '../../../core/utils/wcag_checker.dart';

class WcagScreen extends StatelessWidget {
  final PaletteEntry entry;
  const WcagScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final pairResults = WcagChecker.checkPalette(entry.colors);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('WCAG Check',
            style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Penjelasan singkat
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'WCAG 2.1 mengatur standar kontras warna agar konten mudah dibaca oleh semua orang, termasuk yang memiliki gangguan penglihatan.\n\n'
              '• AAA ✓  → Kontras ≥ 7.0:1 (Terbaik)\n'
              '• AA ✓   → Kontras ≥ 4.5:1 (Standar)\n'
              '• AA Large ✓ → Kontras ≥ 3.0:1 (Teks besar)\n'
              '• Fail ✗  → Kontras < 3.0:1 (Tidak layak)',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.6),
            ),
          ),

          const SizedBox(height: 20),

          // Header palet
          const Text(
            'KOMBINASI WARNA',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Hasil per pasangan warna
          ...pairResults.map((pair) => _WcagPairCard(pair: pair)).toList(),
        ],
      ),
    );
  }
}

class _WcagPairCard extends StatelessWidget {
  final WcagPairResult pair;
  const _WcagPairCard({required this.pair});

  @override
  Widget build(BuildContext context) {
    final c1 = pair.color1;
    final c2 = pair.color2;
    final result = pair.result;

    final color1 = Color.fromRGBO(
        c1['r'] as int, c1['g'] as int, c1['b'] as int, 1.0);
    final color2 = Color.fromRGBO(
        c2['r'] as int, c2['g'] as int, c2['b'] as int, 1.0);

    // Tentukan warna badge berdasarkan rating
    Color badgeColor;
    if (result.passAAA) {
      badgeColor = Colors.green;
    } else if (result.passAA) {
      badgeColor = Colors.lightGreen;
    } else if (result.contrastRatio >= 3.0) {
      badgeColor = Colors.orange;
    } else {
      badgeColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Preview warna berdampingan
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: Row(
              children: [
                // Warna 1
                Expanded(
                  child: Container(
                    height: 60,
                    color: color1,
                    alignment: Alignment.center,
                    child: Text(
                      c1['hex'] as String,
                      style: TextStyle(
                        color: WcagChecker.shouldUseWhiteText(
                          c1['r'] as int,
                          c1['g'] as int,
                          c1['b'] as int,
                        )
                            ? Colors.white
                            : Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Warna 2
                Expanded(
                  child: Container(
                    height: 60,
                    color: color2,
                    alignment: Alignment.center,
                    child: Text(
                      c2['hex'] as String,
                      style: TextStyle(
                        color: WcagChecker.shouldUseWhiteText(
                          c2['r'] as int,
                          c2['g'] as int,
                          c2['b'] as int,
                        )
                            ? Colors.white
                            : Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info kontras
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Ratio
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Contrast Ratio',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 11)),
                    Text(
                      '${result.contrastRatio.toStringAsFixed(2)}:1',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // Badge rating
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor, width: 1.5),
                  ),
                  child: Text(
                    result.rating,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}