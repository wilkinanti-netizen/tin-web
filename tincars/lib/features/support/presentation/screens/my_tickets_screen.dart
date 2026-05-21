import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mis Tickets de Soporte',
          style: GoogleFonts.outfit(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: userId == null
          ? const Center(child: Text('Inicia sesión para ver tus tickets'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('support_tickets')
                  .where('user_id', isEqualTo: userId)
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.support_agent_rounded, size: 60, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No tienes tickets de soporte',
                          style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isPending = data['status'] == 'pending';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isPending ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPending ? Icons.access_time_rounded : Icons.check_circle_rounded,
                            color: isPending ? Colors.orange : Colors.green,
                          ),
                        ),
                        title: Text(
                          data['category']?.toString().toUpperCase() ?? 'OTRO',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            data['description'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TicketChatScreen(
                                ticketId: docs[index].id,
                                ticketData: data,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class TicketChatScreen extends StatefulWidget {
  final String ticketId;
  final Map<String, dynamic> ticketData;

  const TicketChatScreen({super.key, required this.ticketId, required this.ticketData});

  @override
  State<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<TicketChatScreen> {
  final _replyController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('support_tickets').doc(widget.ticketId).snapshots(),
      builder: (context, ticketSnapshot) {
        if (!ticketSnapshot.hasData) {
          return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
        }

        final currentTicketData = ticketSnapshot.data!.data() as Map<String, dynamic>? ?? widget.ticketData;
        final isPending = currentTicketData['status'] == 'pending';

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F7),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              children: [
                Text(
                  'Soporte TinCars',
                  style: GoogleFonts.outfit(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 16),
                ),
                Text(
                  isPending ? 'Chat Abierto' : 'Ticket Cerrado',
                  style: GoogleFonts.outfit(
                    color: isPending ? Colors.blueAccent : Colors.grey,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Info del ticket
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Categoría: ${currentTicketData['category']?.toString().toUpperCase()}',
                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Mensaje Inicial del Usuario
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A1C1E),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Tú (Problema inicial)', style: GoogleFonts.outfit(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              currentTicketData['description'] ?? '',
                              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Historial de mensajes (Stream)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('support_tickets')
                          .doc(widget.ticketId)
                          .collection('messages')
                          .orderBy('created_at', descending: false)
                          .snapshots(),
                      builder: (context, msgSnapshot) {
                        if (!msgSnapshot.hasData) return const SizedBox.shrink();
                        
                        final messages = msgSnapshot.data!.docs;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: messages.map((msgDoc) {
                            final msg = msgDoc.data() as Map<String, dynamic>;
                            final isUser = msg['sender_type'] == 'user';
                            
                            return Align(
                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isUser ? const Color(0xFF1A1C1E) : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: Radius.circular(isUser ? 20 : 4),
                                    bottomRight: Radius.circular(isUser ? 4 : 20),
                                  ),
                                  boxShadow: isUser ? [] : [
                                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (!isUser)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.support_agent_rounded, size: 14, color: Colors.blueAccent),
                                          const SizedBox(width: 4),
                                          Text('Soporte TinCars', style: GoogleFonts.outfit(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                        ],
                                      )
                                    else
                                      Text('Tú', style: GoogleFonts.outfit(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
                                    
                                    const SizedBox(height: 4),
                                    Text(
                                      msg['text'] ?? '',
                                      style: GoogleFonts.outfit(fontSize: 14, color: isUser ? Colors.white : Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Área de escritura
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
                  ],
                ),
                child: SafeArea(
                  child: isPending
                      ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _replyController,
                                minLines: 1,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Escribe tu respuesta...',
                                  hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: _isSending
                                  ? null
                                  : () async {
                                      final text = _replyController.text.trim();
                                      if (text.isEmpty) return;
                                      
                                      setState(() => _isSending = true);
                                      _replyController.clear();
                                      
                                      try {
                                        await FirebaseFirestore.instance
                                            .collection('support_tickets')
                                            .doc(widget.ticketId)
                                            .collection('messages')
                                            .add({
                                          'text': text,
                                          'sender_type': 'user',
                                          'created_at': FieldValue.serverTimestamp(),
                                        });
                                      } catch (e) {
                                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                      }
                                      
                                      if (mounted) setState(() => _isSending = false);
                                    },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: const BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: _isSending
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, color: Colors.grey.shade400),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'El ticket ha sido cerrado. Abre uno nuevo si necesitas más ayuda.',
                                  style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
