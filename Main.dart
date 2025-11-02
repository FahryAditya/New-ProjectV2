// Pastikan dependencies berikut ada di pubspec.yaml:
// google_fonts, font_awesome_flutter, url_launcher, lottie, flutter_animate

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';

void main() {
  runApp(const MyPortfolioApp());
}

// --- Konfigurasi Desain ---
const Color kPrimaryColor = Color(0xFF2563EB); // Biru Profesional
const Color kBackgroundColor = Color(0xFFF8FAFC); // Putih Abu Lembut
const Color kTextColor = Color(0xFF334155); // Abu Gelap
const double kMaxContentWidth = 1200;

// --- Komponen Utama Aplikasi ---

class MyPortfolioApp extends StatelessWidget {
  const MyPortfolioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutterfolio - Fahry Aditya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: kPrimaryColor,
        // Font Poppins untuk keseluruhan aplikasi
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: kTextColor),
        ),
        scaffoldBackgroundColor: kBackgroundColor,
        useMaterial3: true,
      ),
      home: const PortfolioScreen(),
    );
  }
}

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  final GlobalKey _heroKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _projectsKey = GlobalKey();
  final GlobalKey _skillsKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  // State untuk kontak form
  final _contactFormKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Controller untuk animasi Parallax/Melayang di Hero Section
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // Fungsi untuk scroll ke Section
  void _scrollToSection(GlobalKey key) {
    Scrollable.ensureVisible(
      key.currentContext!,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  // Fungsi untuk membuka link (termasuk email)
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka link: $url')),
        );
      }
    }
  }

  // Fungsi untuk mengirim email (simulasi form)
  void _sendEmail() {
    if (_contactFormKey.currentState!.validate()) {
      final name = _nameController.text;
      final email = _emailController.text;
      final message = _messageController.text;

      final mailtoLink = 'mailto:jessica.putri@email.com?subject=Pesan dari $name (via Portofolio)&body=Nama: $name%0AEmail: $email%0A%0APesan:%0A$message';
      _launchUrl(mailtoLink);
      
      // Reset form setelah mengirim
      _nameController.clear();
      _emailController.clear();
      _messageController.clear();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesan Anda siap dikirim melalui email!'), backgroundColor: kPrimaryColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      appBar: _buildAppBar(isMobile),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // 1. Hero Section
                _buildHeroSection(isMobile).animate(key: _heroKey).fadeIn(duration: 800.ms),
                const SizedBox(height: 80),

                // 2. Tentang Saya (About Me)
                _buildSectionTitle('Tentang Saya'),
                _buildAboutMeSection(isMobile).animate(key: _aboutKey).slideX(begin: 0.1, duration: 800.ms).fadeIn(),
                const SizedBox(height: 80),

                // 3. Skill Bar Animasi
                _buildSectionTitle('Keahlian Teknis'),
                _buildSkillsSection().animate(key: _skillsKey).slideY(begin: 0.1, duration: 800.ms).fadeIn(),
                const SizedBox(height: 80),

                // 4. Proyek Unggulan
                _buildSectionTitle('Proyek Unggulan'),
                _buildProjectsSection(isMobile).animate(key: _projectsKey).slideY(begin: 0.1, duration: 800.ms).fadeIn(),
                const SizedBox(height: 80),

                // 5. Sertifikat
                _buildSectionTitle('Sertifikat & Penghargaan'),
                _buildCertificatesSection().animate().slideX(begin: -0.1, duration: 800.ms).fadeIn(),
                const SizedBox(height: 80),

                // 6. Kontak
                _buildSectionTitle('Hubungi Saya'),
                _buildContactSection().animate(key: _contactKey).slideY(begin: 0.1, duration: 800.ms).fadeIn(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _scrollToSection(_heroKey),
        backgroundColor: kPrimaryColor,
        child: const FaIcon(FontAwesomeIcons.arrowUp, color: Colors.white),
      ),
    );
  }

  // --- Widget Komponen ---

  // AppBar / Navbar Mini
  PreferredSizeWidget _buildAppBar(bool isMobile) {
    return AppBar(
      title: Text('flutterfolio.dev', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: kPrimaryColor, fontSize: isMobile ? 20 : 28)),
      centerTitle: false,
      elevation: 0,
      backgroundColor: kBackgroundColor,
      actions: isMobile
          ? null
          : [
              _buildNavButton('Tentang', _aboutKey),
              _buildNavButton('Keahlian', _skillsKey),
              _buildNavButton('Proyek', _projectsKey),
              _buildNavButton('Kontak', _contactKey),
              const SizedBox(width: 40),
            ],
    );
  }

  Widget _buildNavButton(String title, GlobalKey key) {
    return TextButton(
      onPressed: () => _scrollToSection(key),
      child: Text(title, style: GoogleFonts.poppins(color: kTextColor.withOpacity(0.8), fontWeight: FontWeight.w500)),
    );
  }

  // Judul Bagian Reusable
  Widget _buildSectionTitle(String title) {
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.only(bottom: 40),
      child: Text(
        '# $title',
        style: GoogleFonts.sora(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: kPrimaryColor,
        ),
      ),
    );
  }

  // 1. Hero Section
  Widget _buildHeroSection(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 60, vertical: 80),
      child: isMobile 
        ? Column(children: [_buildHeroText(), _buildFloatingImage(isMobile)])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildHeroText()),
              Expanded(flex: 2, child: _buildFloatingImage(isMobile)),
            ],
          ),
    );
  }

  Widget _buildHeroText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Halo, Saya Fahry Aditya',
          style: GoogleFonts.sora(fontSize: 24, color: kTextColor.withOpacity(0.7)),
        ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),
        const SizedBox(height: 10),
        Text(
          'Mobile App \nDeveloper',
          style: GoogleFonts.sora(
            fontSize: 68,
            fontWeight: FontWeight.w900,
            color: kTextColor,
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.1),
        const SizedBox(height: 20),
        Text(
          'Menciptakan pengalaman digital yang efisien dan menarik menggunakan Flutter, fokus pada UI/UX yang intuitif.',
          style: GoogleFonts.inter(fontSize: 18, color: kTextColor.withOpacity(0.7)),
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () => _scrollToSection(_contactKey),
          icon: const FaIcon(FontAwesomeIcons.handshake, color: Colors.white, size: 18),
          label: const Text('Mulai Kolaborasi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingImage(bool isMobile) {
    return Center(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          // Efek melayang sederhana (Parallax simulasi)
          final offset = Offset(0, 10 * _animationController.value * 2 - 10);
          return Transform.translate(
            offset: offset,
            child: Container(
              width: isMobile ? 200 : 300,
              height: isMobile ? 200 : 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimaryColor.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(color: kPrimaryColor.withOpacity(0.2), blurRadius: 40, spreadRadius: 5),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  'https://uploads.onecompiler.io/43k3cj6jv/43zv4nwbv/113114.jpg.', // Ganti dengan foto profil asli
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(child: Text("Foto Profil", style: TextStyle(color: kPrimaryColor))),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 2. Tentang Saya (About Me)
  Widget _buildAboutMeSection(bool isMobile) {
    final softSkills = ['Teamwork', 'Problem-Solving', 'Fast-Learner', 'Attention to Detail', 'Adaptability'];

    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saya adalah seorang pengembang Flutter yang antusias, berfokus pada pembangunan aplikasi mobile dan web yang memiliki kinerja tinggi dan desain yang menyenangkan. Saya percaya bahwa efisiensi kode harus berjalan seiring dengan pengalaman pengguna yang intuitif.',
            style: GoogleFonts.inter(fontSize: 18, height: 1.6, color: kTextColor.withOpacity(0.9)),
            textAlign: isMobile ? TextAlign.justify : TextAlign.start,
          ),
          const SizedBox(height: 30),
          Text(
            'Soft Skills:',
            style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryColor),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: softSkills.map((skill) => Chip(
              label: Text(skill, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              backgroundColor: kPrimaryColor.withOpacity(0.1),
              side: const BorderSide(color: kPrimaryColor),
            ).animate().scale(duration: 500.ms)).toList(),
          ),
        ],
      ),
    );
  }

  // 3. Skill Bar Animasi
  Widget _buildSkillsSection() {
    final skillsData = [
      {'name': 'Flutter / Dart', 'level': 0.95, 'icon': FontAwesomeIcons.mobileScreenButton, 'color': Colors.blue},
      {'name': 'UI/UX Design (Figma)', 'level': 0.85, 'icon': FontAwesomeIcons.palette, 'color': Colors.pink},
      {'name': 'MySQL', 'level': 0.80, 'icon': FontAwesomeIcons.fire, 'color': Colors.amber},
      {'name': 'HTML, CSS, JS', 'level': 0.70, 'icon': FontAwesomeIcons.code, 'color': Colors.deepOrange},
    ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: skillsData.map((skill) => _buildSkillBar(
          skill['name'] as String,
          skill['level'] as double,
          skill['icon'] as IconData,
          skill['color'] as Color,
        )).toList(),
      ),
    );
  }

  Widget _buildSkillBar(String label, double level, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(label, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: kTextColor)),
              const Spacer(),
              Text('${(level * 100).toInt()}%', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          // Animasi Progress Bar
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: level),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 12,
                  backgroundColor: kTextColor.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 4. Proyek Unggulan
  Widget _buildProjectsSection(bool isMobile) {
    final projects = [
      {'title': 'Smart Data Parser App', 'desc': 'Analisis & visualisasi data CSV/JSON di mobile. (Flutter, Firebase)', 'link': 'https://github.com/project-parser'},
      {'title': 'E-Commerce UI Redesign', 'desc': 'Peningkatan konversi 15% melalui alur checkout yang optimal. (Figma, UX)', 'link': 'https://dribbble.com/ecom-redesign'},
      {'title': 'IoT Monitor Dashboard', 'desc': 'Dashboard web real-time untuk sensor IoT. (Flutter Web, ChartJS)', 'link': 'https://github.com/iot-monitor'},
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: projects.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isMobile ? 1 : 3,
          childAspectRatio: 1.2,
          crossAxisSpacing: 25,
          mainAxisSpacing: 25,
        ),
        itemBuilder: (context, index) {
          final project = projects[index];
          return _buildProjectCard(project['title']!, project['desc']!, project['link']!);
        },
      ),
    );
  }

  Widget _buildProjectCard(String title, String description, String link) {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _launchUrl(link),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FaIcon(FontAwesomeIcons.solidStar, color: kPrimaryColor.withOpacity(0.6), size: 30),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryColor)),
                  const SizedBox(height: 10),
                  Text(description, style: GoogleFonts.inter(color: kTextColor.withOpacity(0.8))),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Lihat Proyek', style: GoogleFonts.poppins(color: kPrimaryColor, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  const FaIcon(FontAwesomeIcons.arrowRight, size: 14, color: kPrimaryColor),
                ],
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 800.ms),
    );
  }

  // 5. Sertifikat
  Widget _buildCertificatesSection() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
         
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () {
              // Simulasi download PDF (tidak bisa real di lingkungan ini)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Simulasi: Dokumen PDF sedang diunduh!'), backgroundColor: Colors.green),
              );
            },
            icon: const FaIcon(FontAwesomeIcons.download, color: Colors.white, size: 18),
            label: const Text('Download Resume PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateTile({required String title, required String issuer, required IconData icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: kTextColor.withOpacity(0.05), blurRadius: 10)],
      ),
      child: ListTile(
        leading: FaIcon(icon, color: Colors.amber.shade700, size: 24),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Text(issuer),
      ),
    );
  }

  // 6. Kontak
  Widget _buildContactSection() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Form(
        key: _contactFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Siap untuk proyek inovatif berikutnya? Kirimkan pesan Anda!', style: GoogleFonts.inter(fontSize: 18, color: kTextColor.withOpacity(0.8))),
            const SizedBox(height: 30),
            _buildTextField(_nameController, 'Nama Lengkap', FontAwesomeIcons.user, false),
            _buildTextField(_emailController, 'Alamat Email', FontAwesomeIcons.envelope, true),
            _buildTextField(_messageController, 'Pesan Anda', FontAwesomeIcons.comment, false, maxLines: 5),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                onPressed: _sendEmail,
                icon: const FaIcon(FontAwesomeIcons.paperPlane, color: Colors.white, size: 18),
                label: const Text('Kirim Pesan Otomatis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 50),
            _buildSocialLinks(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isEmail, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: FaIcon(icon, size: 18, color: kPrimaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: kTextColor.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kPrimaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '$label wajib diisi.';
          }
          if (isEmail && !value.contains('@')) {
            return 'Format email tidak valid.';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSocialLinks() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          
          _buildSocialIcon(FontAwesomeIcons.github, 'https://github.com/FahryAditya'),
          _buildSocialIcon(FontAwesomeIcons.instagram, ''),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: InkWell(
        onTap: () => _launchUrl(url),
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kPrimaryColor.withOpacity(0.4), width: 1.5),
            color: Colors.white,
          ),
          child: FaIcon(icon, color: kPrimaryColor, size: 24),
        ),
      ).animate().scale(duration: 500.ms, delay: 200.ms),
    );
  }
}
