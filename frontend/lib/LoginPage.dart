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
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Text(
              "FA Humboldt Spray Wall Database",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          //email
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: "Email"),
          ),
          // password
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: "Password"),
            obscureText: true,
          ),
          // login button
          const SizedBox(height: 12),

          ElevatedButton(onPressed: _submitLogin, child: const Text("Login")),

          const SizedBox(height: 12),

          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.4,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterPage()),
                ),
                hoverColor: Colors.grey.withOpacity(0.2),
                splashColor: Colors.grey.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  child: Center(
                    child: Text(
                      "Don't have an account? Sign Up",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
