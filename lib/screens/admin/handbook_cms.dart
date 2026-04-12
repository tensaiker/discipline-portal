import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class HandbookCMS extends StatefulWidget {
  const HandbookCMS({super.key});

  @override
  State<HandbookCMS> createState() => _HandbookCMSState();
}

class _HandbookCMSState extends State<HandbookCMS> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _bgCream = const Color(0xFFE5DCD3);
  final Color _iconBg = const Color(0xFFFFF9E7);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- SEARCH & ADD SECTION ---
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2C1AF),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) =>
                            setState(() => _searchQuery = v.toLowerCase()),
                        decoration: const InputDecoration(
                          hintText: "Search policies...",
                          prefixIcon: Icon(Icons.search, color: Colors.black54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  _buildAddButton(),
                ],
              ),
            ),
          ),
        ),

        // --- THE LIVE LIST ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('handbook')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Center(child: Text("Connection Error"));
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              var docs = snapshot.data!.docs.where((doc) {
                return doc['title'].toString().toLowerCase().contains(
                  _searchQuery,
                );
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  return Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: _buildPolicyCard(docs[index]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getIcon(data['iconName']), color: _darkBrown),
        ),
        title: Text(
          data['title'],
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          data['subtitle'],
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'edit') _showFormDialog(doc: doc);
            if (val == 'delete') doc.reference.delete();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text("Edit")),
            const PopupMenuItem(
              value: 'delete',
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton.icon(
      onPressed: () => _showFormDialog(),
      icon: const Icon(Icons.add, size: 18),
      label: const Text("Add Policy"),
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkBrown,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showFormDialog({DocumentSnapshot? doc}) {
    final tC = TextEditingController(text: doc != null ? doc['title'] : "");
    final sC = TextEditingController(text: doc != null ? doc['subtitle'] : "");
    final cC = TextEditingController(text: doc != null ? doc['content'] : "");
    String selectedIcon = doc != null
        ? (doc.data() as Map<String, dynamic>)['iconName'] ?? "person"
        : "person";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: Text(
            doc == null ? "Create New Policy" : "Edit Policy",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(tC, "Title (e.g. Uniform Policy)"),
                const SizedBox(height: 12),
                _dialogField(sC, "Subtitle (Brief summary)"),
                const SizedBox(height: 12),
                _dialogField(cC, "Full Content", maxLines: 5),
                const SizedBox(height: 15),

                // --- ADDED ICON PICKER ---
                DropdownButtonFormField<String>(
                  value: selectedIcon,
                  items: ["person", "gavel", "clock", "block"]
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Row(
                            children: [
                              Icon(_getIcon(e), color: _darkBrown, size: 20),
                              const SizedBox(width: 10),
                              Text(e[0].toUpperCase() + e.substring(1)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedIcon = v!),
                  decoration: InputDecoration(
                    labelText: "Policy Icon",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _darkBrown),
                onPressed: () async {
                  var payload = {
                    'title': tC.text,
                    'subtitle': sC.text,
                    'content': cC.text,
                    'iconName': selectedIcon,
                    'timestamp': FieldValue.serverTimestamp(),
                  };
                  doc == null
                      ? await FirebaseFirestore.instance
                            .collection('handbook')
                            .add(payload)
                      : await doc.reference.update(payload);
                  Navigator.pop(context);
                },
                child: const Text(
                  "Save Policy",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  IconData _getIcon(String? name) {
    switch (name) {
      case 'gavel':
        return Icons.gavel_rounded;
      case 'clock':
        return Icons.access_time_filled_rounded;
      case 'block':
        return Icons.block_flipped;
      default:
        return Icons.person_rounded;
    }
  }
}
