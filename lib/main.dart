import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const AplikasiTugasMahasiswa());
}

class AplikasiTugasMahasiswa extends StatefulWidget {
  const AplikasiTugasMahasiswa({super.key});

  @override
  State<AplikasiTugasMahasiswa> createState() => _AplikasiTugasMahasiswaState();
}

class _AplikasiTugasMahasiswaState extends State<AplikasiTugasMahasiswa> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _toggleTheme() async {
    setState(() => _isDarkMode = !_isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My College Tasks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HalamanDaftarTugas(onToggleTheme: _toggleTheme, isDarkMode: _isDarkMode),
    );
  }
}

// Model Data Tugas
class Tugas {
  String nama;
  String mataKuliah;
  DateTime deadline;
  String prioritas;
  bool sudahSelesai;

  Tugas({
    required this.nama,
    required this.mataKuliah,
    required this.deadline,
    required this.prioritas,
    this.sudahSelesai = false,
  });

  Map<String, dynamic> toJson() => {
        'nama': nama,
        'mataKuliah': mataKuliah,
        'deadline': deadline.toIso8601String(),
        'prioritas': prioritas,
        'sudahSelesai': sudahSelesai,
      };

  factory Tugas.fromJson(Map<String, dynamic> json) => Tugas(
        nama: json['nama'],
        mataKuliah: json['mataKuliah'],
        deadline: DateTime.parse(json['deadline']),
        prioritas: json['prioritas'],
        sudahSelesai: json['sudahSelesai'],
      );
}

// Halaman Utama
class HalamanDaftarTugas extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const HalamanDaftarTugas({super.key, required this.onToggleTheme, required this.isDarkMode});

  @override
  State<HalamanDaftarTugas> createState() => _HalamanDaftarTugasState();
}

class _HalamanDaftarTugasState extends State<HalamanDaftarTugas>
    with SingleTickerProviderStateMixin {
  final List<Tugas> _daftarTugas = [];
  final List<Tugas> _daftarTugasTampil = [];
  String _queryPencarian = '';
  int _tabIndex = 0;
  bool _isLoading = true;
  bool _isSearching = false;

  late TabController _tabController;

  final TextEditingController _ctrlNama = TextEditingController();
  final TextEditingController _ctrlMakul = TextEditingController();
  DateTime _tanggalDipilih = DateTime.now().add(const Duration(days: 1));
  String _prioritasDipilih = 'Sedang';

  static const String _kunciPenyimpanan = 'daftar_tugas';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChange);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _muatDataDariPenyimpanan();
  }

  void _onTabChange() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _tabIndex = _tabController.index;
      _perbaruiDaftarTampil();
    });
  }

  Future<void> _muatDataDariPenyimpanan() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dataString = prefs.getString(_kunciPenyimpanan);
    if (dataString != null) {
      final List<dynamic> jsonList = jsonDecode(dataString);
      setState(() {
        _daftarTugas.clear();
        _daftarTugas.addAll(jsonList.map((item) => Tugas.fromJson(item)).toList());
        _daftarTugas.sort((a, b) => a.deadline.compareTo(b.deadline));
        _perbaruiDaftarTampil();
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _simpanDataKePenyimpanan() async {
    final prefs = await SharedPreferences.getInstance();
    final String dataString = jsonEncode(_daftarTugas.map((t) => t.toJson()).toList());
    await prefs.setString(_kunciPenyimpanan, dataString);
  }

  void _perbaruiDaftarTampil() {
    List<Tugas> sumber = [];
    if (_tabIndex == 0) {
      sumber = _daftarTugas;
    } else if (_tabIndex == 1) {
      sumber = _daftarTugas.where((t) => !t.sudahSelesai).toList();
    } else {
      sumber = _daftarTugas.where((t) => t.sudahSelesai).toList();
    }

    if (_queryPencarian.isEmpty) {
      _daftarTugasTampil.clear();
      _daftarTugasTampil.addAll(sumber);
    } else {
      _daftarTugasTampil.clear();
      _daftarTugasTampil.addAll(
        sumber.where((tugas) =>
            tugas.nama.toLowerCase().contains(_queryPencarian.toLowerCase()) ||
            tugas.mataKuliah.toLowerCase().contains(_queryPencarian.toLowerCase())),
      );
    }
  }

  void _tambahTugas(String prioritas) async {
    if (_ctrlNama.text.isNotEmpty && _ctrlMakul.text.isNotEmpty) {
      setState(() {
        _daftarTugas.add(Tugas(
          nama: _ctrlNama.text,
          mataKuliah: _ctrlMakul.text,
          deadline: _tanggalDipilih,
          prioritas: prioritas,
        ));
        _daftarTugas.sort((a, b) => a.deadline.compareTo(b.deadline));
        _perbaruiDaftarTampil();
      });
      await _simpanDataKePenyimpanan();
    }
  }

  void _ubahStatusTugas(Tugas tugas) async {
    setState(() {
      tugas.sudahSelesai = !tugas.sudahSelesai;
      _perbaruiDaftarTampil();
    });
    await _simpanDataKePenyimpanan();
  }

  void _hapusTugas(Tugas tugas) async {
    setState(() {
      _daftarTugas.remove(tugas);
      _perbaruiDaftarTampil();
    });
    await _simpanDataKePenyimpanan();
  }

  // ------------------- FITUR HAPUS MASSAL -------------------
  Future<void> _hapusSemuaTugasSelesai() async {
    final jumlah = _daftarTugas.where((t) => t.sudahSelesai).length;
    if (jumlah == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada tugas yang selesai')),
      );
      return;
    }

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Tugas Selesai'),
        content: Text('Anda akan menghapus $jumlah tugas yang sudah selesai.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (konfirmasi == true) {
      setState(() {
        _daftarTugas.removeWhere((t) => t.sudahSelesai);
        _perbaruiDaftarTampil();
      });
      await _simpanDataKePenyimpanan();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$jumlah tugas selesai dihapus')),
      );
    }
  }

  Future<void> _hapusSemuaTugas() async {
    if (_daftarTugas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada tugas')),
      );
      return;
    }

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Semua Tugas'),
        content: Text('Anda akan menghapus semua ${_daftarTugas.length} tugas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Semua', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (konfirmasi == true) {
      setState(() {
        _daftarTugas.clear();
        _perbaruiDaftarTampil();
      });
      await _simpanDataKePenyimpanan();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua tugas telah dihapus')),
      );
    }
  }

  Color _warnaPrioritas(String prioritas) {
    switch (prioritas) {
      case 'Tinggi':
        return const Color(0xFFFF6B6B);
      case 'Sedang':
        return const Color(0xFFFFB347);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  void _munculkanBottomSheet({Tugas? tugasEdit}) {
    final bool isEdit = tugasEdit != null;
    if (isEdit) {
      _ctrlNama.text = tugasEdit.nama;
      _ctrlMakul.text = tugasEdit.mataKuliah;
      _tanggalDipilih = tugasEdit.deadline;
      _prioritasDipilih = tugasEdit.prioritas;
    } else {
      _ctrlNama.clear();
      _ctrlMakul.clear();
      _tanggalDipilih = DateTime.now().add(const Duration(days: 1));
      _prioritasDipilih = 'Sedang';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BottomSheetContent(
        ctrlNama: _ctrlNama,
        ctrlMakul: _ctrlMakul,
        tanggalDipilih: _tanggalDipilih,
        prioritasDipilih: _prioritasDipilih,
        isEdit: isEdit,
        onSave: (String prioritasTerpilih) async {
          _prioritasDipilih = prioritasTerpilih;
          
          if (isEdit) {
            setState(() {
              tugasEdit.nama = _ctrlNama.text;
              tugasEdit.mataKuliah = _ctrlMakul.text;
              tugasEdit.deadline = _tanggalDipilih;
              tugasEdit.prioritas = prioritasTerpilih;
              _daftarTugas.sort((a, b) => a.deadline.compareTo(b.deadline));
              _perbaruiDaftarTampil();
            });
            await _simpanDataKePenyimpanan();
          } else {
            _tambahTugas(prioritasTerpilih);
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalTugas = _daftarTugas.length;
    int selesai = _daftarTugas.where((t) => t.sudahSelesai).length;
    int aktif = totalTugas - selesai;
    double progres = totalTugas == 0 ? 0.0 : selesai / totalTugas;

    int tinggi = _daftarTugas.where((t) => t.prioritas == 'Tinggi').length;
    int sedang = _daftarTugas.where((t) => t.prioritas == 'Sedang').length;
    int rendah = _daftarTugas.where((t) => t.prioritas == 'Rendah').length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
title: !_isSearching
    ? LayoutBuilder(
        builder: (context, constraints) {
          final fontSize = constraints.maxWidth < 250 ? 14.0 : (constraints.maxWidth < 300 ? 16.0 : 20.0);
          return Text(
            'Daftar Tugas',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        },
      )
    : TextField(
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Cari...',
          hintStyle: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) {
          setState(() {
            _queryPencarian = value;
            _perbaruiDaftarTampil();
          });
        },
      ),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
       actions: [
        if (!_isSearching)
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 22),
            onPressed: () {
              setState(() {
                _isSearching = true;
                _queryPencarian = ''; // reset query
              });
            },
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          )
        else
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            onPressed: () {
              setState(() {
                _isSearching = false;
                _queryPencarian = '';
                _perbaruiDaftarTampil(); // kembalikan daftar tanpa filter
              });
            },
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        // ... tombol dark mode & popup menu tetap sama

          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode, size: 22),
            onPressed: widget.onToggleTheme,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              if (value == 'hapus_selesai') {
                _hapusSemuaTugasSelesai();
              } else if (value == 'hapus_semua') {
                _hapusSemuaTugas();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'hapus_selesai',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 20),
                    SizedBox(width: 8),
                    Text('Hapus tugas selesai'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'hapus_semua',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 20),
                    SizedBox(width: 8),
                    Text('Hapus semua tugas'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(200), // Cukup tinggi untuk menampung semua konten
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF6C63FF),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 400;
                return Column(
                  children: [
                    if (isSmall)
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatCard(
                                title: 'Total',
                                value: totalTugas,
                                icon: Icons.assignment_rounded,
                                color: Colors.white,
                                isSmall: true,
                              ),
                              _StatCard(
                                title: 'Aktif',
                                value: aktif,
                                icon: Icons.pending_actions_rounded,
                                color: const Color(0xFFFFB347),
                                isSmall: true,
                              ),
                              _StatCard(
                                title: 'Selesai',
                                value: selesai,
                                icon: Icons.check_circle_rounded,
                                color: const Color(0xFF4CAF50),
                                isSmall: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatCard(
                            title: 'Total',
                            value: totalTugas,
                            icon: Icons.assignment_rounded,
                            color: Colors.white,
                            isSmall: false,
                          ),
                          _StatCard(
                            title: 'Aktif',
                            value: aktif,
                            icon: Icons.pending_actions_rounded,
                            color: const Color(0xFFFFB347),
                            isSmall: false,
                          ),
                          _StatCard(
                            title: 'Selesai',
                            value: selesai,
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF4CAF50),
                            isSmall: false,
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircularPercentIndicator(
                          radius: 20.0,
                          lineWidth: 4.0,
                          percent: progres,
                          center: Text(
                            '${(progres * 100).toInt()}%',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                          progressColor: Colors.white,
                          backgroundColor: Colors.white30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Kamu telah menyelesaikan $selesai dari $totalTugas tugas',
                            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: isSmall ? 6.0 : 12.0,
                      runSpacing: 4.0,
                      alignment: WrapAlignment.center,
                      children: [
                        _PriorityBadge(label: 'Tinggi', count: tinggi, color: const Color(0xFFFF6B6B), isSmall: isSmall),
                        _PriorityBadge(label: 'Sedang', count: sedang, color: const Color(0xFFFFB347), isSmall: isSmall),
                        _PriorityBadge(label: 'Rendah', count: rendah, color: const Color(0xFF4CAF50), isSmall: isSmall),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF6C63FF),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF6C63FF),
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Semua'),
                Tab(text: 'Aktif'),
                Tab(text: 'Selesai'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _daftarTugasTampil.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/empty_illustration.png',
                              height: 120,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.assignment_outlined,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _queryPencarian.isEmpty
                                  ? 'Belum ada tugas nih.\nYuk, tambahkan yang pertama!'
                                  : 'Tidak ditemukan tugas yang cocok.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        itemCount: _daftarTugasTampil.length,
                        itemBuilder: (context, index) {
                          final tugas = _daftarTugasTampil[index];
                          return _TugasCard(
                            tugas: tugas,
                            warnaPrioritas: _warnaPrioritas(tugas.prioritas),
                            onToggle: () => _ubahStatusTugas(tugas),
                            onDelete: () => _hapusTugas(tugas),
                            onEdit: () => _munculkanBottomSheet(tugasEdit: tugas),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _munculkanBottomSheet(),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Tugas Baru',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ------------------- WIDGET STAT CARD -------------------
class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final bool isSmall;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = isSmall ? 16.0 : 20.0;
    final padding = isSmall
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    final titleFontSize = isSmall ? 10.0 : 12.0;
    final valueFontSize = isSmall ? 14.0 : 18.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: titleFontSize,
                  color: Colors.white70,
                ),
              ),
              Text(
                value.toString(),
                style: GoogleFonts.poppins(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------- WIDGET PRIORITY BADGE -------------------
class _PriorityBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isSmall;

  const _PriorityBadge({
    required this.label,
    required this.count,
    required this.color,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final padding = isSmall
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 4);
    final fontSize = isSmall ? 10.0 : 12.0;
    final dotSize = isSmall ? 6.0 : 8.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ($count)',
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------- WIDGET TUGAS CARD -------------------
class _TugasCard extends StatelessWidget {
  final Tugas tugas;
  final Color warnaPrioritas;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TugasCard({
    required this.tugas,
    required this.warnaPrioritas,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOverdue = tugas.deadline.isBefore(DateTime.now()) && !tugas.sudahSelesai;
    return Dismissible(
      key: Key(tugas.nama + tugas.deadline.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        final bool? konfirmasi = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hapus Tugas?'),
            content: Text('Tugas "${tugas.nama}" akan dihapus permanen.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        return konfirmasi ?? false;
      },
      onDismissed: (direction) {
        onDelete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tugas.nama} dihapus')),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: tugas.sudahSelesai ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                onEdit();
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onToggle();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tugas.sudahSelesai
                              ? const Color(0xFF4CAF50)
                              : Colors.transparent,
                          border: Border.all(
                            color: tugas.sudahSelesai
                                ? const Color(0xFF4CAF50)
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: tugas.sudahSelesai
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tugas.nama,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: tugas.sudahSelesai
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: tugas.sudahSelesai
                                  ? Colors.grey.shade500
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.book_outlined,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tugas.mataKuliah,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: isOverdue ? Colors.red : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${tugas.deadline.day}/${tugas.deadline.month}/${tugas.deadline.year}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: isOverdue ? Colors.red : Colors.grey.shade600,
                                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              if (isOverdue) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Terlambat',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: warnaPrioritas.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tugas.prioritas,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: warnaPrioritas,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: onEdit,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------- BOTTOM SHEET CONTENT -------------------
class _BottomSheetContent extends StatefulWidget {
  final TextEditingController ctrlNama;
  final TextEditingController ctrlMakul;
  final DateTime tanggalDipilih;
  final String prioritasDipilih;
  final bool isEdit;
  final Function(String) onSave;

  const _BottomSheetContent({
    required this.ctrlNama,
    required this.ctrlMakul,
    required this.tanggalDipilih,
    required this.prioritasDipilih,
    required this.isEdit,
    required this.onSave,
  });

  @override
  State<_BottomSheetContent> createState() => _BottomSheetContentState();
}

class _BottomSheetContentState extends State<_BottomSheetContent> {
  late DateTime _tanggal;
  late String _prioritas;

  @override
  void initState() {
    super.initState();
    _tanggal = widget.tanggalDipilih;
    _prioritas = widget.prioritasDipilih;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.isEdit ? 'Edit Tugas' : 'Tambah Tugas Baru',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: widget.ctrlNama,
                style: GoogleFonts.poppins(),
                decoration: InputDecoration(
                  labelText: 'Nama Tugas',
                  hintText: 'Misal: Buat Makalah Bab 2',
                  prefixIcon: const Icon(Icons.task_rounded, color: Color(0xFF6C63FF)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: widget.ctrlMakul,
                style: GoogleFonts.poppins(),
                decoration: InputDecoration(
                  labelText: 'Mata Kuliah',
                  hintText: 'Misal: Pemrograman Mobile',
                  prefixIcon: const Icon(Icons.book_rounded, color: Color(0xFF6C63FF)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: Color(0xFF6C63FF)),
                  const SizedBox(width: 10),
                  Text(
                    'Deadline:',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _tanggal,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _tanggal = picked);
                      }
                    },
                    icon: const Icon(Icons.edit_calendar_rounded),
                    label: Text(
                      '${_tanggal.day}/${_tanggal.month}/${_tanggal.year}',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.flag_rounded, color: Color(0xFF6C63FF)),
                  const SizedBox(width: 10),
                  Text(
                    'Prioritas:',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: DropdownButton<String>(
                      value: _prioritas,
                      underline: const SizedBox(),
                      items: ['Tinggi', 'Sedang', 'Rendah'].map((e) {
                        return DropdownMenuItem(
                          value: e,
                          child: Text(e, style: GoogleFonts.poppins()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _prioritas = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (widget.ctrlNama.text.isEmpty || widget.ctrlMakul.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nama dan Mata Kuliah harus diisi')),
                      );
                      return;
                    }
                    widget.onSave(_prioritas);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    widget.isEdit ? 'Simpan Perubahan' : 'Tambah Tugas',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}