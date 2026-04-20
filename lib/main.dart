import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_options.dart';
import 'notification_service.dart';
import 'pdf_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.init();
  await NotificationService.scheduleAbsenReminder();
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
      home: StreamBuilder<User?>(
  stream: FirebaseAuth.instance.authStateChanges(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshot.hasData) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(snapshot.data!.uid)
            .get(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Cek apakah field 'nama' sudah diisi
          final data = userSnap.data?.data() as Map<String, dynamic>?;
          final sudahIsiData = data != null &&
              (data['nama'] ?? '').toString().isNotEmpty;
          if (sudahIsiData) {
            return const HomePage();
          }
          return const IsiDataDiriPage();
        },
      );
    }
    return const LoginPage();
  },
),
    );
  }
}

// ===================== LOGIN =====================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isRegister = false;
  String _errorMessage = '';

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      if (_isRegister) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const IsiDataDiriPage()),
          );
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Terjadi kesalahan';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final uid = userCredential.user!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final data = doc.data();
      final sudahIsiData =
          data != null && (data['nama'] ?? '').toString().isNotEmpty;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                sudahIsiData ? const HomePage() : const IsiDataDiriPage(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Terjadi kesalahan');
    } catch (e) {
      setState(() => _errorMessage = 'Login Google gagal: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.work, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'MagangKu',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRegister ? 'Buat akun baru' : 'Masuk ke akun kamu',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_isRegister ? 'Daftar' : 'Masuk'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        setState(() => _isRegister = !_isRegister),
                    child: Text(
                      _isRegister
                          ? 'Sudah punya akun? Masuk'
                          : 'Belum punya akun? Daftar',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Row(children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('atau',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata,
                          size: 28, color: Colors.red),
                      label: const Text('Masuk dengan Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ===================== ISI DATA DIRI (ONBOARDING) =====================
class IsiDataDiriPage extends StatefulWidget {
  const IsiDataDiriPage({super.key});

  @override
  State<IsiDataDiriPage> createState() => _IsiDataDiriPageState();
}

class _IsiDataDiriPageState extends State<IsiDataDiriPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  final _namaController = TextEditingController();
  final _nimController = TextEditingController();
  final _prodiController = TextEditingController();
  final _universityController = TextEditingController();
  final _emailController = TextEditingController();
  final _noHpController = TextEditingController();

  Future<void> _simpan() async {
    if (_namaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama lengkap wajib diisi!')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser!.uid;
      await _db.collection('users').doc(uid).set({
        'nama': _namaController.text.trim(),
        'nim': _nimController.text.trim(),
        'prodi': _prodiController.text.trim(),
        'universitas': _universityController.text.trim(),
        'email': _emailController.text.trim(),
        'noHp': _noHpController.text.trim(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildField(String label, TextEditingController controller,
      IconData icon, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
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
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.person, size: 36, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Lengkapi Data Diri',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  Text(
                    'Isi data diri kamu sebelum mulai',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  _buildField('Nama Lengkap *', _namaController, Icons.person),
                  _buildField('NIM', _nimController, Icons.badge,
                      keyboardType: TextInputType.number),
                  _buildField('Program Studi', _prodiController, Icons.school),
                  _buildField('Universitas', _universityController,
                      Icons.account_balance),
                  _buildField('Email', _emailController, Icons.email,
                      keyboardType: TextInputType.emailAddress),
                  _buildField('No. HP', _noHpController, Icons.phone,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _simpan,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_circle),
                      label: const Text('Mulai Magang!'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
  final _auth = FirebaseAuth.instance;

  Future<void> _absen(String status) async {
  print('=== ABSEN DIPANGGIL: $status ===');
  final uid = _auth.currentUser?.uid;
  print('=== UID: $uid ===');
  if (uid == null) {
    print('=== UID NULL, USER TIDAK LOGIN ===');
    return;
  }
  try {
    final now = DateTime.now();
    await _db.collection('users').doc(uid).collection('absensi').add({
      'status': status,
      'tanggal': '${now.day}/${now.month}/${now.year}',
      'timestamp': FieldValue.serverTimestamp(),
    });
    print('=== ABSEN BERHASIL DISIMPAN ===');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Absen $status berhasil!')),
    );
  } catch (e) {
    print('=== ERROR ABSEN: $e ===');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal absen: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
if (uid == null) return const SizedBox();
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
                  .collection('users')
                  .doc(uid)
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
  final _auth = FirebaseAuth.instance;
  final _kegiatanController = TextEditingController();

  Future<void> _tambahLogbook() async {
    if (_kegiatanController.text.isEmpty) return;
    final uid = _auth.currentUser!.uid;
    final now = DateTime.now();
    await _db.collection('users').doc(uid).collection('logbook').add({
      'kegiatan': _kegiatanController.text,
      'tanggal': '${now.day}/${now.month}/${now.year}',
      'timestamp': FieldValue.serverTimestamp(),
    });
    _kegiatanController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logbook berhasil disimpan!')),
    );
  }

  Future<void> _hapusLogbook(String docId) async {
    final uid = _auth.currentUser!.uid;
    await _db
        .collection('users')
        .doc(uid)
        .collection('logbook')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await PdfService.exportLogbook();
              },
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              label: const Text('Export PDF'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.red.shade50,
              ),
            ),
          ),
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
                  .collection('users')
                  .doc(uid)
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
                        leading:
                            const Icon(Icons.book, color: Colors.blue),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
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
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  final _namaController = TextEditingController();
  final _nimController = TextEditingController();
  final _prodiController = TextEditingController();
  final _universityController = TextEditingController();
  final _emailController = TextEditingController();
  final _noHpController = TextEditingController();

  String? _photoUrl;
  File? _pickedPhotoFile;
  bool _isEditing = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadDataDiri();
  }

  Future<void> _loadDataDiri() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _namaController.text = data['nama'] ?? '';
        _nimController.text = data['nim'] ?? '';
        _prodiController.text = data['prodi'] ?? '';
        _universityController.text = data['universitas'] ?? '';
        _emailController.text = data['email'] ?? '';
        _noHpController.text = data['noHp'] ?? '';
        _photoUrl = data['photoUrl'] as String?;
      });
    }
  }

  Future<void> _pickProfileImage({required ImageSource source}) async {
    // Request permission first
    PermissionStatus permissionStatus;
    if (source == ImageSource.camera) {
      permissionStatus = await Permission.camera.request();
    } else {
      permissionStatus = await Permission.photos.request();
    }

    if (!permissionStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin akses ditolak. Silakan berikan izin untuk mengakses galeri/kamera.')),
        );
      }
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada gambar yang dipilih')),
          );
        }
        return;
      }

      // Validate file exists and is not empty
      final file = File(pickedFile.path);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File gambar tidak ditemukan')),
          );
        }
        return;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File gambar kosong')),
          );
        }
        return;
      }

      setState(() {
        _isUploadingPhoto = true;
        _pickedPhotoFile = file;
      });

      final uid = _auth.currentUser!.uid;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${uid}_$timestamp.jpg';
      final ref = _storage.ref().child('profile_photos').child(fileName);

      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploadedBy': uid},
      );

      final uploadTask = ref.putFile(file, metadata);
      await uploadTask;

      final url = await ref.getDownloadURL();

      await _db.collection('users').doc(uid).set({
        'photoUrl': url,
        'photoUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _photoUrl = url;
        _pickedPhotoFile = null;
      });

      await _loadDataDiri();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diperbarui!')),
        );
      }
    } catch (e) {
      // Error uploading photo
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal upload foto: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _pickProfileImageFromGallery() async {
    await _pickProfileImage(source: ImageSource.gallery);
  }

  Future<void> _pickProfileImageFromCamera() async {
    await _pickProfileImage(source: ImageSource.camera);
  }

  Future<void> _deleteProfileImage() async {
    final uid = _auth.currentUser!.uid;
    setState(() => _isUploadingPhoto = true);
    try {
      final ref = _storage.ref().child('profile_photos').child('$uid.jpg');
      await ref.delete();
    } catch (_) {
      // Ignore if file not found or delete fails; still remove Firestore field.
    }
    try {
      await _db.collection('users').doc(uid).set({
        'photoUrl': FieldValue.delete(),
      }, SetOptions(merge: true));
      setState(() {
        _photoUrl = null;
        _pickedPhotoFile = null;
      });
      await _loadDataDiri();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil dihapus.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus foto profil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _simpanDataDiri() async {
    final uid = _auth.currentUser!.uid;
    await _db.collection('users').doc(uid).set({
      'nama': _namaController.text,
      'nim': _nimController.text,
      'prodi': _prodiController.text,
      'universitas': _universityController.text,
      'email': _emailController.text,
      'noHp': _noHpController.text,
    }, SetOptions(merge: true));
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
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.blue,
                backgroundImage: _pickedPhotoFile != null
                    ? FileImage(_pickedPhotoFile!)
                    : (_photoUrl != null && _photoUrl!.isNotEmpty
                        ? NetworkImage(_photoUrl!)
                        : null),
                child: _pickedPhotoFile == null &&
                        (_photoUrl == null || _photoUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 50, color: Colors.white)
                    : null,
              ),
              if (_isEditing)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _isUploadingPhoto ? null : _pickProfileImageFromGallery,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      child: Icon(
                        _isUploadingPhoto ? Icons.hourglass_top : Icons.photo_library,
                        size: 18,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_isEditing) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isUploadingPhoto ? null : _pickProfileImageFromCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Kamera'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  ),
                ),
                if (_photoUrl != null && _photoUrl!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isUploadingPhoto ? null : _deleteProfileImage,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Hapus'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding:
                          const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 20),
          _buildField('Nama Lengkap', _namaController, Icons.person),
          _buildField('NIM', _nimController, Icons.badge),
          _buildField('Program Studi', _prodiController, Icons.school),
          _buildField('Universitas', _universityController,
              Icons.account_balance),
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
  final _auth = FirebaseAuth.instance;
  final _namaController = TextEditingController();
  final _penerbitController = TextEditingController();
  final _tahunController = TextEditingController();

  Future<void> _tambahSertifikasi() async {
    if (_namaController.text.isEmpty) return;
    final uid = _auth.currentUser!.uid;
    await _db
        .collection('users')
        .doc(uid)
        .collection('sertifikasi')
        .add({
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
    final uid = _auth.currentUser!.uid;
    await _db
        .collection('users')
        .doc(uid)
        .collection('sertifikasi')
        .doc(docId)
        .delete();
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
    final uid = _auth.currentUser!.uid;
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('users')
            .doc(uid)
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
                  subtitle:
                      Text('${data['penerbit']} • ${data['tahun']}'),
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