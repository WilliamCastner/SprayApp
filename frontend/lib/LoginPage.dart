import 'package:flutter/material.dart';
import 'package:namer_app/AuthService.dart';
import 'package:namer_app/RegisterPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Get auth service
  final authService = AuthService();

  // Text controller
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _submitLogin() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    //Attempt login
    try {
      await authService.signInWithEmailPassword(email, password);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        children: [
          //email
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: "Email"),
          ),
          // password
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: "Password"),
          ),
          // login button
          const SizedBox(height: 12),

          ElevatedButton(onPressed: _submitLogin, child: const Text("Login")),

          const SizedBox(height: 12),

          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegisterPage()),
            ),
            child: Center(child: Text("Don't have an account? Sign Up")),
          ),
        ],
      ),
    );
  }
}
