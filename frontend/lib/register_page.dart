import 'package:flutter/material.dart';
import 'package:namer_app/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final authService = AuthService();

  // Text controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPassword = TextEditingController();

  void _submitSignUp() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPassword.text;

    if (password != confirmPassword) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords don't match.")));
      return;
    }

    try {
      await authService.signUpWithEmailPassword(email, password, username);

      // Update display name / username if provided

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        children: [
          // Username / Display Name
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: "Display Name"),
          ),
          const SizedBox(height: 12),

          // Email
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: "Email"),
          ),
          const SizedBox(height: 12),

          // Password
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: "Password"),
            obscureText: true,
          ),
          const SizedBox(height: 12),

          // Confirm Password
          TextField(
            controller: _confirmPassword,
            decoration: const InputDecoration(labelText: "Confirm Password"),
            obscureText: true,
          ),
          const SizedBox(height: 20),

          // Sign Up Button
          ElevatedButton(
            onPressed: _submitSignUp,
            child: const Text("Sign Up"),
          ),
        ],
      ),
    );
  }
}
