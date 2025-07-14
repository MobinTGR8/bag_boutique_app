// main.dart - Version 9.6
// Resolved all linter warnings and optimized code for modern best practices.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:intl/intl.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

// --- INSTRUCTIONS FOR THIS VERSION ---
//
// 1.  No new packages are needed.
// 2.  REPLACE your main.dart with this new code.
// 3.  REPLACE your test/widget_test.dart with the second code block provided.
// 4.  RE-RUN THE APP. All warnings should be resolved.
//
// --- END OF INSTRUCTIONS ---


// --- App Theme & Colors ---
class AppTheme {
  static const Color primary = Color(0xFF111111);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFFF5F5F5);
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF757575);

  static ThemeData get theme {
    return ThemeData(
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 1,
        shadowColor: Color(0x1A000000),
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: accent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary),
        ),
        labelStyle: const TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        StreamProvider<User?>.value(
          value: FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
        ChangeNotifierProxyProvider<User?, Cart>(
          create: (context) => Cart(null),
          update: (context, user, previousCart) => previousCart!..updateUser(user),
        ),
      ],
      child: const BagBoutiqueApp(),
    ),
  );
}

// --- DATA MODELS ---
class Product {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String description;
  final List<String> tags;
  final String? modelUrl;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.description,
    required this.tags,
    this.modelUrl,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? 'No Name',
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'] ?? 'https://placehold.co/400x400?text=No+Image',
      description: data['description'] ?? 'No description available.',
      tags: List<String>.from(data['tags'] ?? []),
      modelUrl: data['modelUrl'],
    );
  }
}

class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  factory CartItem.fromMap(Map<String, dynamic> data) {
    return CartItem(
      id: data['id'],
      name: data['name'],
      price: (data['price'] ?? 0).toDouble(),
      quantity: data['quantity'] ?? 1,
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }
}

class Order {
  final String id;
  final double amount;
  final List<CartItem> products;
  final DateTime dateTime;
  final String shippingAddress;

  Order({
    required this.id,
    required this.amount,
    required this.products,
    required this.dateTime,
    required this.shippingAddress,
  });

  factory Order.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Order(
      id: doc.id,
      amount: (data['amount'] as num).toDouble(),
      products: (data['products'] as List<dynamic>)
          .map((item) => CartItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      shippingAddress: data['shippingAddress'] ?? 'No address provided',
    );
  }
}


// --- CART PROVIDER ---
class Cart extends ChangeNotifier {
  String? userId;
  Map<String, CartItem> _items = {};

  Cart(this.userId);

  Map<String, CartItem> get items => {..._items};
  int get itemCount => _items.values.fold(0, (currentSum, item) => currentSum + item.quantity);
  double get totalPrice {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  void updateUser(User? user) {
    if (user != null && user.uid != userId) {
      userId = user.uid;
      _items.clear();
      _loadCartFromFirestore();
    } else if (user == null && userId != null) {
      userId = null;
      _items.clear();
      notifyListeners();
    }
  }

  Future<void> _loadCartFromFirestore() async {
    if (userId == null) return;
    final cartSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(userId).collection('cart').get();
    _items = {for (var doc in cartSnapshot.docs) doc.id: CartItem.fromMap(doc.data())};
    notifyListeners();
  }

  Future<void> addItem(Product product) async {
    if (userId == null) return;
    final productId = product.id;
    if (_items.containsKey(productId)) {
      _items.update(
        productId,
        (existingItem) => CartItem(
          id: existingItem.id,
          name: existingItem.name,
          price: existingItem.price,
          quantity: existingItem.quantity + 1,
        ),
      );
    } else {
      _items.putIfAbsent(
        productId,
        () => CartItem(
          id: product.id,
          name: product.name,
          price: product.price,
        ),
      );
    }
    await _saveItemToFirestore(_items[productId]!);
    notifyListeners();
  }

  Future<void> updateQuantity(String productId, int newQuantity) async {
    if (userId == null || !_items.containsKey(productId)) return;
    if (newQuantity > 0) {
      _items.update(productId, (item) => CartItem(id: item.id, name: item.name, price: item.price, quantity: newQuantity));
      await _saveItemToFirestore(_items[productId]!);
    } else {
      await removeItem(productId);
    }
    notifyListeners();
  }

  Future<void> removeItem(String productId) async {
    if (userId == null) return;
    _items.remove(productId);
    await FirebaseFirestore.instance.collection('users').doc(userId).collection('cart').doc(productId).delete();
    notifyListeners();
  }

  Future<void> _saveItemToFirestore(CartItem item) async {
    if (userId == null) return;
    await FirebaseFirestore.instance.collection('users').doc(userId).collection('cart').doc(item.id).set(item.toMap());
  }

  Future<void> clearCart() async {
    if (userId == null) return;
    final cartDocs = await FirebaseFirestore.instance.collection('users').doc(userId).collection('cart').get();
    for (var doc in cartDocs.docs) {
      await doc.reference.delete();
    }
    _items.clear();
    notifyListeners();
  }
}

// --- APP STRUCTURE ---
class BagBoutiqueApp extends StatelessWidget {
  const BagBoutiqueApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Bag Boutique',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    if (user != null) {
      return const MainNavigator();
    } else {
      return const LoginScreen();
    }
  }
}

enum AppState { welcome, quiz, analysis, home }

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});
  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  AppState _appState = AppState.welcome;
  List<String> _userStyleTags = [];

  void _startQuiz() => setState(() => _appState = AppState.quiz);
  void _skipQuiz() => setState(() {
        _userStyleTags = [];
        _appState = AppState.home;
      });
  void _finishQuiz(List<String> tags) {
    setState(() {
      _appState = AppState.analysis;
      _userStyleTags = tags;
    });
    Future.delayed(const Duration(seconds: 2), () => setState(() => _appState = AppState.home));
  }

  @override
  Widget build(BuildContext context) {
    switch (_appState) {
      case AppState.welcome:
        return WelcomeScreen(onStartQuiz: _startQuiz, onSkip: _skipQuiz);
      case AppState.quiz:
        return QuizScreen(onQuizCompleted: _finishQuiz);
      case AppState.analysis:
        return const AnalysisScreen();
      case AppState.home:
        return HomeScreen(userTags: _userStyleTags);
    }
  }
}


// --- SCREENS AND WIDGETS ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  String _email = '';
  String _password = '';
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        if (_isLogin) {
          await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email, password: _password);
        } else {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email, password: _password);
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = e.message;
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'THE BAG BOUTIQUE',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, letterSpacing: 2),
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    key: const ValueKey('email'),
                    decoration: const InputDecoration(labelText: 'Email Address'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value!.isEmpty || !value.contains('@') ? 'Please enter a valid email' : null,
                    onSaved: (value) => _email = value!,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('password'),
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) => value!.length < 6 ? 'Password must be at least 6 characters' : null,
                    onSaved: (value) => _password = value!,
                  ),
                  const SizedBox(height: 32),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  else
                    ElevatedButton(
                      onPressed: _submit,
                      child: Text(_isLogin ? 'LOGIN' : 'CREATE ACCOUNT'),
                    ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                    ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? 'Don\'t have an account? Sign up' : 'Already have an account? Login'),
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

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('MY PROFILE')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.accent,
              child: Icon(Icons.person_outline, size: 40, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(user?.email ?? 'No email found', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 32),
            ProfileMenuItem(
              title: 'My Orders',
              icon: Icons.shopping_bag_outlined,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderHistoryScreen())),
            ),
            ProfileMenuItem(
              title: 'Settings',
              icon: Icons.settings_outlined,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
            ),
            ProfileMenuItem(
              title: 'Help & Support',
              icon: Icons.help_outline,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpScreen())),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                 style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade200),
                ),
                child: const Text('LOG OUT'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class ProfileMenuItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const ProfileMenuItem({super.key, required this.title, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.textSecondary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      onTap: onTap,
    );
  }
}


class HomeScreen extends StatefulWidget {
  final List<String> userTags;
  const HomeScreen({super.key, required this.userTags});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  late Stream<QuerySnapshot> _productsStream;
  @override
  void initState() {
    super.initState();
    Query productsQuery = FirebaseFirestore.instance.collection('products');
    if (widget.userTags.isNotEmpty) {
      productsQuery = productsQuery.where('tags', arrayContainsAny: widget.userTags);
    }
    _productsStream = productsQuery.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('THE BAG BOUTIQUE'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              showSearch(context: context, delegate: ProductSearchDelegate());
            },
            icon: const Icon(Icons.search_outlined),
          ),
          const CartIcon(),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _productsStream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No products found.', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)));
          
          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.65,
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (BuildContext context, int index) {
              final product = Product.fromFirestore(snapshot.data!.docs[index]);
              return ProductCard(
                product: product,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product))),
              );
            },
          );
        },
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const ProductCard({super.key, required this.product, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: AppTheme.accent,
              child: Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary));
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary, size: 40);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            product.name.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 13, letterSpacing: 0.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text('৳${product.price.toInt()}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name.toUpperCase()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.width,
              child: Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 80, color: AppTheme.accent),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name.toUpperCase(),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, letterSpacing: 1),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '৳${product.price.toInt()}',
                    style: const TextStyle(fontSize: 22, color: AppTheme.textPrimary, fontWeight: FontWeight.w400),
                  ),
                  const Divider(height: 48),
                  if (product.modelUrl != null && product.modelUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.view_in_ar),
                        label: const Text('VIEW IN YOUR SPACE'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ARViewScreen(modelUrl: product.modelUrl!)),
                          );
                        },
                      ),
                    ),
                  const Text('DESCRIPTION', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, letterSpacing: 0.8)),
                  const SizedBox(height: 12),
                  Text(product.description, style: const TextStyle(fontSize: 15, height: 1.7, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              Provider.of<Cart>(context, listen: false).addItem(product);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product.name} added to cart!'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  action: SnackBarAction(
                    label: 'VIEW CART',
                    textColor: AppTheme.accent,
                    onPressed: () {
                      if(context.mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
                      }
                    },
                  ),
                ),
              );
            },
            child: const Text('ADD TO CART'),
          ),
        ),
      ),
    );
  }
}

class CartIcon extends StatelessWidget {
  const CartIcon({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<Cart>(
      builder: (context, cart, child) => Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
          ),
          if (cart.itemCount > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  cart.itemCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<Cart>(
      builder: (context, cart, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('SHOPPING CART')),
          body: cart.items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 80, color: AppTheme.accent),
                      SizedBox(height: 20),
                      Text('Your cart is empty.', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  itemBuilder: (ctx, i) {
                    final item = cart.items.values.toList()[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                const SizedBox(height: 8),
                                Text('৳${item.price.toInt()}', style: const TextStyle(color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(icon: const Icon(Icons.remove, size: 20), onPressed: () => cart.updateQuantity(item.id, item.quantity - 1)),
                              Text('${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              IconButton(icon: const Icon(Icons.add, size: 20), onPressed: () => cart.updateQuantity(item.id, item.quantity + 1)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
          bottomNavigationBar: cart.items.isEmpty
              ? null
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), spreadRadius: 1, blurRadius: 10)],
                  ),
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOTAL', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, letterSpacing: 1)),
                            Text('৳${cart.totalPrice.toInt()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                          child: const Text('PROCEED TO CHECKOUT'),
                        )
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _address = '';
  String _phone = '';
  bool _isLoading = false;

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    final cart = Provider.of<Cart>(context, listen: false);
    final user = Provider.of<User?>(context, listen: false);

    try {
      await FirebaseFirestore.instance.collection('orders').add({
        'userId': user!.uid,
        'amount': cart.totalPrice,
        'dateTime': Timestamp.now(),
        'shippingAddress': '$_name\n$_address\n$_phone',
        'products': cart.items.values.map((item) => item.toMap()).toList(),
      });

      await cart.clearCart();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const OrderConfirmationScreen()),
          (route) => false,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not place order. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SHIPPING DETAILS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
                onSaved: (value) => _name = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Full Address'),
                maxLines: 3,
                validator: (value) => value!.isEmpty ? 'Please enter your address' : null,
                onSaved: (value) => _address = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Please enter your phone number' : null,
                onSaved: (value) => _phone = value!,
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _placeOrder,
                  child: const Text('PLACE ORDER'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 100),
              const SizedBox(height: 24),
              const Text(
                'Order Placed Successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Thank you for your purchase. You can view your order details in your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthWrapper()),
                  (route) => false,
                ),
                child: const Text('CONTINUE SHOPPING'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('MY ORDERS')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').where('userId', isEqualTo: user!.uid).orderBy('dateTime', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('An error occurred.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('You have no past orders.', style: TextStyle(fontSize: 18, color: Colors.grey)),
            );
          }
          final List<Order> orders = [];
          for (var doc in snapshot.data!.docs) {
            try {
              orders.add(Order.fromFirestore(doc));
            } catch (e) {
              // Gracefully handle parsing errors
            }
          }
          if (orders.isEmpty && snapshot.data!.docs.isNotEmpty) {
            return const Center(child: Text('Could not display orders due to a data error.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ExpansionTile(
                  title: Text('Order on ${DateFormat.yMMMd().format(order.dateTime)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Total: ৳${order.amount.toInt()}'),
                  childrenPadding: const EdgeInsets.all(16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...order.products.map((prod) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${prod.quantity} x ${prod.name}'),
                              Text('৳${(prod.price * prod.quantity).toInt()}'),
                            ],
                          ),
                        )),
                    const Divider(height: 24),
                    const Text('Shipped to:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(order.shippingAddress, style: const TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onStartQuiz;
  final VoidCallback onSkip;
  const WelcomeScreen({super.key, required this.onStartQuiz, required this.onSkip});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text(
                'Find Your\nPerfect Bag',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, height: 1.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'Answer a few questions to get a personalized collection just for you.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onStartQuiz,
                child: const Text('TAKE THE STYLE QUIZ'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onSkip,
                child: const Text('SKIP FOR NOW'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final Function(List<String>) onQuizCompleted;
  const QuizScreen({super.key, required this.onQuizCompleted});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}
class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  final List<String> _selectedTags = [];
  final List<Map<String, dynamic>> _questions = [ {'question': 'Which occasion are you shopping for?', 'answers': [ {'text': 'Work & Professional', 'tag': 'work', 'icon': Icons.business_center_outlined}, {'text': 'Weekend Casual', 'tag': 'casual', 'icon': Icons.weekend_outlined}, {'text': 'Evening & Events', 'tag': 'evening', 'icon': Icons.nightlife}, {'text': 'Travel & Adventure', 'tag': 'travel', 'icon': Icons.explore_outlined}, ] }, {'question': 'What\'s your go-to color palette?', 'answers': [ {'text': 'Classic Neutrals', 'tag': 'neutral-color', 'icon': Icons.color_lens_outlined}, {'text': 'Bright & Bold', 'tag': 'bold-color', 'icon': Icons.flare_outlined}, {'text': 'Pretty Pastels', 'tag': 'pastel-color', 'icon': Icons.filter_vintage_outlined}, {'text': 'Earthy Tones', 'tag': 'earth-tone', 'icon': Icons.eco_outlined}, ] }, {'question': 'Which style speaks to you?', 'answers': [ {'text': 'Modern Minimalist', 'tag': 'minimalist', 'icon': Icons.square_foot_outlined}, {'text': 'Classic & Timeless', 'tag': 'classic', 'icon': Icons.account_balance_outlined}, {'text': 'Boho Chic', 'tag': 'boho', 'icon': Icons.auto_awesome_outlined}, {'text': 'Sporty & Functional', 'tag': 'sporty', 'icon': Icons.fitness_center_outlined}, ] } ];
  void _answerQuestion(String tag) { _selectedTags.add(tag); if (_currentQuestionIndex < _questions.length - 1) { setState(() { _currentQuestionIndex++; }); } else { widget.onQuizCompleted(_selectedTags); } }
  @override
  Widget build(BuildContext context) {
    final questionData = _questions[_currentQuestionIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('STYLE QUIZ (${_currentQuestionIndex + 1}/${_questions.length})'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              questionData['question'],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: questionData['answers'].length,
                itemBuilder: (context, index) {
                  final answer = questionData['answers'][index];
                  return GestureDetector(
                    onTap: () => _answerQuestion(answer['tag']),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(answer['icon'], size: 40, color: AppTheme.textSecondary),
                          const SizedBox(height: 12),
                          Text(answer['text'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 24),
            Text(
              'Curating your collection...',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SettingsTile(
            title: 'Manage Account',
            subtitle: 'Update your profile information',
            icon: Icons.person_outline,
            onTap: () {},
          ),
          SettingsTile(
            title: 'Notifications',
            subtitle: 'Manage push notifications',
            icon: Icons.notifications_outlined,
            onTap: () {},
            trailing: Switch(value: true, onChanged: (val) {}, activeColor: AppTheme.primary),
          ),
           SettingsTile(
            title: 'Dark Mode',
            subtitle: 'Enable or disable dark theme',
            icon: Icons.dark_mode_outlined,
            onTap: () {},
            trailing: Switch(value: false, onChanged: (val) {}, activeColor: AppTheme.primary),
          ),
          const Divider(height: 40),
           SettingsTile(
            title: 'Privacy Policy',
            subtitle: 'Read our privacy policy',
            icon: Icons.privacy_tip_outlined,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// Helper widget for settings tiles
class SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;

  const SettingsTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.textSecondary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HELP & SUPPORT')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          Text(
            'Frequently Asked Questions',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          FaqTile(
            question: 'How do I track my order?',
            answer: 'You can track your order status from the "My Orders" section in your profile. We will also send you email updates as your order is processed and shipped.',
          ),
          FaqTile(
            question: 'What is your return policy?',
            answer: 'We offer a 14-day return policy for all unused items in their original packaging. Please contact our support team to initiate a return.',
          ),
          FaqTile(
            question: 'How long does shipping take?',
            answer: 'Standard shipping within Bangladesh typically takes 3-5 business days. Express shipping options are also available at checkout.',
          ),
          FaqTile(
            question: 'Do you ship internationally?',
            answer: 'Currently, we only ship within Bangladesh. We are working on expanding our shipping options to more countries in the future.',
          ),
        ],
      ),
    );
  }
}

// Helper widget for FAQ tiles
class FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const FaqTile({super.key, required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppTheme.accent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(answer, style: const TextStyle(color: AppTheme.textSecondary, height: 1.5)),
          )
        ],
      ),
    );
  }
}

// Search Delegate for product search functionality
class ProductSearchDelegate extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) {
    return AppTheme.theme.copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: AppTheme.textSecondary),
        border: InputBorder.none,
      ),
      appBarTheme: AppTheme.theme.appBarTheme.copyWith(
        backgroundColor: AppTheme.surface,
      )
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return Container();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snapshot.data!.docs;
        if (results.isEmpty) {
          return Center(child: Text('No results found for "$query"'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.65,
          ),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final product = Product.fromFirestore(results[index]);
            return ProductCard(
              product: product,
              onTap: () {
                close(context, null); // Close search
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product)),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildResults(context);
  }
}

// AR View Screen
class ARViewScreen extends StatefulWidget {
  final String modelUrl;
  const ARViewScreen({super.key, required this.modelUrl});

  @override
  State<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen> {
  late ARObjectManager arObjectManager;
  late ARAnchorManager arAnchorManager;
  late ARSessionManager arSessionManager;

  @override
  void dispose() {
    arSessionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR View'),
        backgroundColor: Colors.black.withAlpha(128),
      ),
      body: ARView(
        onARViewCreated: onARViewCreated,
        planeDetectionConfig: PlaneDetectionConfig.horizontal,
      ),
    );
  }

  void onARViewCreated(
      ARSessionManager sessionManager,
      ARObjectManager objectManager,
      ARAnchorManager anchorManager,
      ARLocationManager locationManager) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;
    arAnchorManager = anchorManager;

    arSessionManager.onPlaneOrPointTap = onPlaneOrPointTapped;
  }

  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hitTestResults) async {
    var singleHitTestResult = hitTestResults.firstWhere(
        (hitTestResult) => hitTestResult.type == ARHitTestResultType.plane);

    var newAnchor = ARPlaneAnchor(transformation: singleHitTestResult.worldTransform);
    bool? didAddAnchor = await arAnchorManager.addAnchor(newAnchor);

    if (didAddAnchor!) {
      var newNode = ARNode(
        type: NodeType.webGLB,
        uri: widget.modelUrl,
        scale: Vector3(0.2, 0.2, 0.2),
        position: Vector3(0.0, 0.0, 0.0),
        rotation: Vector4(0.0, 0.0, 0.0, 1.0),
      );
      arObjectManager.addNode(newNode, planeAnchor: newAnchor);
    }
  }
}
