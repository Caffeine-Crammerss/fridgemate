import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isSignIn = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuad),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'user-not-found':
        return 'No account found with this email. Please sign up.';
      case 'wrong-password':
        return 'Invalid email or password. Please try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'The email or password you entered is incorrect. Please try again.';
    }
  }

  Future<void> signUpUser(String name, String email, String password) async {
    if (name.isEmpty) {
      showErrorSnackBar('Please enter your full name');
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      showErrorSnackBar('Please enter a valid email address');
      return;
    }

    if (password.length < 6) {
      showErrorSnackBar('Password must be at least 6 characters long');
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fullName': name,
          'email': email,
          'uid': user.uid,
        });

        showSuccessSnackBar('Account created successfully! Please sign in.');
        setState(() => _isSignIn = true);
      }
    } on FirebaseAuthException catch (e) {
      showErrorSnackBar(getErrorMessage(e.code));
    } catch (e) {
      showErrorSnackBar('An unexpected error occurred. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> signInUser(String email, String password) async {
    if (email.isEmpty || !email.contains('@')) {
      showErrorSnackBar('Please enter a valid email address');
      return;
    }

    if (password.isEmpty) {
      showErrorSnackBar('Please enter your password');
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          showSuccessSnackBar('Welcome back, ${userDoc['fullName']}!');
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        showErrorSnackBar('Invalid email or password. Please try again.');
      } else {
        showErrorSnackBar(getErrorMessage(e.code));
      }
    } catch (e) {
      showErrorSnackBar('An unexpected error occurred. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepOrange.shade900,
              const Color(0xFF1E1E2C),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        'FridgeMate',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSignIn ? 'Welcome back!' : 'Create your account',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildAuthToggle(),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          key: ValueKey<bool>(_isSignIn),
                          children: [
                            if (!_isSignIn) ...[
                              _buildInputField(
                                controller: nameController,
                                label: 'Full Name',
                                icon: Icons.person_outline_rounded,
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildInputField(
                              controller: emailController,
                              label: 'Email Address',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            _buildInputField(
                              controller: passwordController,
                              label: 'Password',
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                            ),
                            _buildHighlightSection(),
                            const SizedBox(height: 16),
                            _buildActionButton(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthToggle() {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              title: 'Sign In',
              isSelected: _isSignIn,
              onTap: () => setState(() => _isSignIn = true),
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              title: 'Sign Up',
              isSelected: !_isSignIn,
              onTap: () => setState(() => _isSignIn = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: Colors.deepOrange.shade300),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey[400],
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildHighlightSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepOrange.shade700.withOpacity(0.2),
                  Colors.deepPurple.shade900.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: Colors.deepOrange.shade300,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Tracking',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Easy food management & tracking',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSmallHighlight(
                  icon: Icons.inventory_2_outlined,
                  title: 'Track Food',
                  color: Colors.orange.shade300,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmallHighlight(
                  icon: Icons.notifications_active_outlined,
                  title: 'Get Alerts',
                  color: Colors.green.shade300,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmallHighlight(
                  icon: Icons.trending_up_rounded,
                  title: 'Analytics',
                  color: Colors.blue.shade300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallHighlight({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.deepOrange.shade400,
                Colors.deepOrange.shade700,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.deepOrange.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : () {
              if (_isSignIn) {
                signInUser(
                  emailController.text.trim(),
                  passwordController.text.trim(),
                );
              } else {
                signUpUser(
                  nameController.text.trim(),
                  emailController.text.trim(),
                  passwordController.text.trim(),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 12),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                Text(
                  _isLoading
                      ? 'Please wait...'
                      : _isSignIn
                      ? 'Sign In'
                      : 'Create Account',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (!_isLoading)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    child: Icon(
                      _isSignIn ? Icons.login_rounded : Icons.person_add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _isSignIn = !_isSignIn;
                _animationController.reset();
                _animationController.forward();
              });
            },
            child: Text(
              _isSignIn
                  ? "Don't have an account? Sign Up"
                  : "Already have an account? Sign In",
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}