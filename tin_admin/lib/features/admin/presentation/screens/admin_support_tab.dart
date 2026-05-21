import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminSupportTab extends StatefulWidget {
  const AdminSupportTab({super.key});

  @override
  State<AdminSupportTab> createState() => _AdminSupportTabState();
}

class _AdminSupportTabState extends State<AdminSupportTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blueAccent,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'PENDIENTES'),
              Tab(text: 'RESUELTOS'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTicketList('pending'),
              _buildTicketList('resolved'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTicketList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_tickets')
          .where('status', isEqualTo: status)
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
            child: Text(
              status == 'pending' ? 'No hay tickets pendientes.' : 'No hay tickets resueltos.',
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final ticket = docs[index];
            final data = ticket.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: status == 'pending' ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                  child: Icon(
                    status == 'pending' ? Icons.pending_actions : Icons.check_circle,
                    color: status == 'pending' ? Colors.orange : Colors.green,
                  ),
                ),
                title: Text(
                  data['category']?.toString().toUpperCase() ?? 'OTRO',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      data['description'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Usuario: ${data['user_id']}',
                      style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => _showTicketDetails(context, ticket),
              ),
            );
          },
        );
      },
    );
  }

  void _showTicketDetails(BuildContext context, DocumentSnapshot ticket) {
    final data = ticket.data() as Map<String, dynamic>;
    final replyController = TextEditingController();
    
    // Sugerencias de respuestas rápidas
    final List<String> quickReplies = [
      '¡Hola! Soy de soporte TinCars. Lamentamos el inconveniente, ya ajustamos el cobro.',
      '¡Hola! Tu objeto fue reportado al conductor. Te contactaremos con novedades.',
      '¡Hola! Gracias por avisar. Nuestro equipo de seguridad está revisando el caso.',
      '¡Hola! Entendemos tu molestia. Hemos tomado medidas con el conductor.',
      '¡Hola! ¿Podrías brindarnos un poco más de detalle sobre lo sucedido?',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('support_tickets').doc(ticket.id).snapshots(),
          builder: (context, ticketSnapshot) {
            if (!ticketSnapshot.hasData) return const SizedBox.shrink();
            
            final currentTicketData = ticketSnapshot.data!.data() as Map<String, dynamic>? ?? data;
            final isPending = currentTicketData['status'] == 'pending';
            
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 600,
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 40,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        border: Border(bottom: BorderSide(color: isPending ? Colors.orange.shade100 : Colors.green.shade100)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isPending ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPending ? Icons.support_agent_rounded : Icons.check_circle_rounded,
                              color: isPending ? Colors.orange.shade700 : Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TICKET DE SOPORTE',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isPending ? Colors.orange.shade700 : Colors.green.shade700,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                Text(
                                  currentTicketData['category']?.toString().toUpperCase() ?? 'OTRO',
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    
                    // Body / Chat Area
                    Expanded(
                      child: Container(
                        color: Colors.grey.shade50,
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            // Metadata (User & Trip)
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Usuario: ${currentTicketData['user_id']}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600))),
                              ],
                            ),
                            if (currentTicketData['trip_id'] != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.route_outlined, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Viaje: ${currentTicketData['trip_id']}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600))),
                                ],
                              ),
                            ],
                            
                            const SizedBox(height: 24),
                            
                            // Mensaje Inicial
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade200),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                    bottomLeft: Radius.circular(4),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Mensaje Inicial', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text(currentTicketData['description'] ?? '', style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87)),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Stream de mensajes
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('support_tickets')
                                  .doc(ticket.id)
                                  .collection('messages')
                                  .orderBy('created_at', descending: false)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const SizedBox.shrink();
                                final messages = snapshot.data!.docs;
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: messages.map((msgDoc) {
                                    final msg = msgDoc.data() as Map<String, dynamic>;
                                    final isAdmin = msg['sender_type'] == 'admin';
                                    
                                    return Align(
                                      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isAdmin ? Colors.blue.shade50 : Colors.white,
                                          border: isAdmin ? null : Border.all(color: Colors.grey.shade200),
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(20),
                                            topRight: const Radius.circular(20),
                                            bottomLeft: Radius.circular(isAdmin ? 20 : 4),
                                            bottomRight: Radius.circular(isAdmin ? 4 : 20),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isAdmin ? 'Soporte TinCars' : 'Usuario', 
                                              style: GoogleFonts.outfit(
                                                fontSize: 10, 
                                                fontWeight: FontWeight.bold, 
                                                color: isAdmin ? Colors.blue.shade700 : Colors.grey,
                                              )
                                            ),
                                            const SizedBox(height: 4),
                                            Text(msg['text'] ?? '', style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87)),
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
                    ),
                    
                    // Input Area
                    if (isPending)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SUGERENCIAS RÁPIDAS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.2)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 35,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: quickReplies.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ActionChip(
                                      label: Text(quickReplies[index], style: GoogleFonts.outfit(fontSize: 12, color: Colors.blue.shade700)),
                                      backgroundColor: Colors.blue.shade50,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.blue.shade100)),
                                      onPressed: () {
                                        replyController.text = quickReplies[index];
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: replyController,
                                    maxLines: 3,
                                    minLines: 1,
                                    decoration: InputDecoration(
                                      hintText: 'Escribe tu respuesta...',
                                      hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400),
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () async {
                                    final text = replyController.text.trim();
                                    if (text.isEmpty) return;
                                    
                                    replyController.clear();
                                    
                                    final batch = FirebaseFirestore.instance.batch();
                                    
                                    // 1. Agregar mensaje
                                    final msgRef = FirebaseFirestore.instance.collection('support_tickets').doc(ticket.id).collection('messages').doc();
                                    batch.set(msgRef, {
                                      'text': text,
                                      'sender_type': 'admin',
                                      'created_at': FieldValue.serverTimestamp(),
                                    });
                                    
                                    // 2. Notificar al usuario
                                    final notifRef = FirebaseFirestore.instance.collection('notification_jobs').doc();
                                    batch.set(notifRef, {
                                      'target': currentTicketData['user_id'],
                                      'title': 'Soporte TinCars',
                                      'body': 'Nuevo mensaje: $text',
                                      'status': 'pending',
                                      'created_at': FieldValue.serverTimestamp(),
                                    });
                                    
                                    await batch.commit();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: const BoxDecoration(
                                      color: Colors.blueAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await FirebaseFirestore.instance.collection('support_tickets').doc(ticket.id).update({
                                    'status': 'resolved',
                                    'resolved_at': FieldValue.serverTimestamp(),
                                  });
                                  if (context.mounted) Navigator.pop(context);
                                },
                                icon: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 18),
                                label: Text('Cerrar Ticket Definitivamente', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A1C1E),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(24),
                        color: Colors.white,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_outline_rounded, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text('Este ticket ha sido cerrado', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }
}
