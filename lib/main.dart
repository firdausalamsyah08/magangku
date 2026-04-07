import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MagangKu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ===================== HOME =====================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    AktivitasPage(),
    ProfilPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Aktivitas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ===================== AKTIVITAS =====================
class AktivitasPage extends StatefulWidget {
  const AktivitasPage({super.key});

  @override
  State<AktivitasPage> createState() => _AktivitasPageState();
}

class _AktivitasPageState extends State<AktivitasPage>
    with SingleTickerProviderStateMixin {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktivitas'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_today), text: 'Absensi'),
            Tab(icon: Icon(Icons.book), text: 'Logbook'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AbsensiTab(),
          LogbookTab(),
        ],
      ),
    );
  }
}

// ===================== ABSENSI TAB =====================
class AbsensiTab extends StatefulWidget {
  const AbsensiTab({super.key});

  @override
  State<AbsensiTab> createState() => _AbsensiTabState();
}

class _AbsensiTabState extends State<AbsensiTab> {
  final _db = FirebaseFirestore.instance;

  Future<void> _absen(String status) async {
    final now = DateTime.now();
    await _db.collection('absensi').add({
      'status': status,
      'tanggal': '${now.day}/${now.month}/${now.year}',
      'timestamp': FieldValue.serverTimestamp(),
      'nama': 'Peserta Magang',
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Absen $status berhasil!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'Absen Hari Ini',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _absen('Hadir'),
                icon: const Icon(Icons.check_circle, color: Colors.green),
                label: const Text('Hadir'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _absen('Tidak Hadir'),
                icon: const Icon(Icons.cancel, color: Colors.red),
                label: const Text('Tidak Hadir'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Riwayat Absen',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('absensi')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Belum ada riwayat absen'));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isHadir = data['status'] == 'Hadir';
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          isHadir ? Icons.check_circle : Icons.cancel,
                          color: isHadir ? Colors.green : Colors.red,
                        ),
                        title: Text('${data['tanggal']} - ${data['status']}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== LOGBOOK TAB =====================
class LogbookTab extends StatefulWidget {
  const LogbookTab({super.key});

  @override
  State<LogbookTab> createState() => _LogbookTabState();
}

class _LogbookTabState extends State<LogbookTab> {
  final _db = FirebaseFirestore.instance;
  final _kegiatanController = TextEditingController();

  Future<void> _tambahLogbook() async {
    if (_kegiatanController.text.isEmpty) return;
    final now = DateTime.now();
    await _db.collection('logbook').add({
      'kegiatan': _kegiatanController.text,
      'tanggal': '${now.day}/${now.month}/${now.year}',
      'timestamp': FieldValue.serverTimestamp(),
      'nama': 'Peserta Magang',
    });
    _kegiatanController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logbook berhasil disimpan!')),
    );
  }

  Future<void> _hapusLogbook(String docId) async {
    await _db.collection('logbook').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 12),
          TextField(
            controller: _kegiatanController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Tuliskan kegiatan hari ini...',
              border: OutlineInputBorder(),
              labelText: 'Kegiatan',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _tambahLogbook,
              icon: const Icon(Icons.save),
              label: const Text('Simpan Logbook'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Riwayat Logbook',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('logbook')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Belum ada logbook'));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.book, color: Colors.blue),
                        title: Text(data['kegiatan'] ?? ''),
                        subtitle: Text(data['tanggal'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _hapusLogbook(docs[index].id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== PROFIL =====================
class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage>
    with SingleTickerProviderStateMixin {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Data Diri'),
            Tab(icon: Icon(Icons.workspace_premium), text: 'Sertifikasi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DataDiriTab(),
          SertifikasiTab(),
        ],
      ),
    );
  }
}

// ===================== DATA DIRI TAB =====================
class DataDiriTab extends StatefulWidget {
  const DataDiriTab({super.key});

  @override
  State<DataDiriTab> createState() => _DataDiriTabState();
}

class _DataDiriTabState extends State<DataDiriTab> {
  final _db = FirebaseFirestore.instance;
  final _namaController = TextEditingController();
  final _nimController = TextEditingController();
  final _prodiController = TextEditingController();
  final _universityController = TextEditingController();
  final _emailController = TextEditingController();
  final _noHpController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadDataDiri();
  }

  Future<void> _loadDataDiri() async {
    final doc = await _db.collection('profil').doc('dataDiri').get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _namaController.text = data['nama'] ?? '';
        _nimController.text = data['nim'] ?? '';
        _prodiController.text = data['prodi'] ?? '';
        _universityController.text = data['universitas'] ?? '';
        _emailController.text = data['email'] ?? '';
        _noHpController.text = data['noHp'] ?? '';
      });
    }
  }

  Future<void> _simpanDataDiri() async {
    await _db.collection('profil').doc('dataDiri').set({
      'nama': _namaController.text,
      'nim': _nimController.text,
      'prodi': _prodiController.text,
      'universitas': _universityController.text,
      'email': _emailController.text,
      'noHp': _noHpController.text,
    });
    setState(() => _isEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data diri berhasil disimpan!')),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: _isEditing,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const CircleAvatar(
            radius: 45,
            backgroundColor: Colors.blue,
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 20),
          _buildField('Nama Lengkap', _namaController, Icons.person),
          _buildField('NIM', _nimController, Icons.badge),
          _buildField('Program Studi', _prodiController, Icons.school),
          _buildField('Universitas', _universityController, Icons.account_balance),
          _buildField('Email', _emailController, Icons.email),
          _buildField('No. HP', _noHpController, Icons.phone),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _isEditing
                ? ElevatedButton.icon(
                    onPressed: _simpanDataDiri,
                    icon: const Icon(Icons.save),
                    label: const Text('Simpan'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Data Diri'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ===================== SERTIFIKASI TAB =====================
class SertifikasiTab extends StatefulWidget {
  const SertifikasiTab({super.key});

  @override
  State<SertifikasiTab> createState() => _SertifikasiTabState();
}

class _SertifikasiTabState extends State<SertifikasiTab> {
  final _db = FirebaseFirestore.instance;
  final _namaController = TextEditingController();
  final _penerbitController = TextEditingController();
  final _tahunController = TextEditingController();

  Future<void> _tambahSertifikasi() async {
    if (_namaController.text.isEmpty) return;
    await _db.collection('sertifikasi').add({
      'nama': _namaController.text,
      'penerbit': _penerbitController.text,
      'tahun': _tahunController.text,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _namaController.clear();
    _penerbitController.clear();
    _tahunController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sertifikasi berhasil ditambahkan!')),
    );
  }

  Future<void> _hapusSertifikasi(String docId) async {
    await _db.collection('sertifikasi').doc(docId).delete();
  }

  void _showTambahDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Sertifikasi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _namaController,
              decoration: const InputDecoration(
                labelText: 'Nama Sertifikasi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _penerbitController,
              decoration: const InputDecoration(
                labelText: 'Penerbit',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tahunController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tahun',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              _tambahSertifikasi();
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('sertifikasi')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Belum ada sertifikasi'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium,
                      color: Colors.amber),
                  title: Text(data['nama'] ?? ''),
                  subtitle: Text('${data['penerbit']} • ${data['tahun']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _hapusSertifikasi(docs[index].id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showTambahDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}