import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Low Price Finder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Low Price Finder'),
    );
  }
}

class ProductInfo {
  final String title;
  final String description;
  final String imageUrl;

  ProductInfo({
    required this.title,
    required this.description,
    required this.imageUrl,
  });
}

class ProductResult {
  final String price;
  final String source;
  final String link;
  final IconData icon;

  ProductResult({
    required this.price,
    required this.source,
    required this.link,
    required this.icon,
  });
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _scannedCode;
  bool _isLoading = false;
  ProductInfo? _productInfo;
  List<ProductResult> _searchResults = [];
  final TextEditingController _manualCodeController = TextEditingController();
  
  // Region Selection: 'CA' for Canada, 'US' for United States. Defaulting to Canada.
  String _selectedRegion = 'CA';

  @override
  void dispose() {
    _manualCodeController.dispose();
    super.dispose();
  }

  void _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        _scannedCode = result;
      });
      _searchProduct(result);
    }
  }

  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter UPC Code'),
        content: TextField(
          controller: _manualCodeController,
          decoration: const InputDecoration(
            hintText: 'e.g. 012345678901',
            labelText: 'UPC Code',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = _manualCodeController.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(context);
                setState(() {
                  _scannedCode = code;
                });
                _searchProduct(code);
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchProduct(String upc) async {
    setState(() {
      _isLoading = true;
      _productInfo = null;
      _searchResults = [];
    });

    try {
      // Query Open Food Facts API to identify the exact product name and brand details
      final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$upc.json');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      String detectedTitle = '';
      String detectedDescription = '';
      String imageUrl = '';

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          final p = data['product'];
          detectedTitle = p['product_name'] ?? p['generic_name'] ?? '';
          final brands = p['brands'] ?? '';
          final categories = p['categories'] ?? '';
          
          if (detectedTitle.isNotEmpty) {
            detectedDescription = '${brands.isNotEmpty ? brands + " " : ""}$detectedTitle';
          } else if (categories.isNotEmpty) {
            detectedDescription = categories.split(',').first;
          }
          imageUrl = p['image_front_url'] ?? p['image_url'] ?? '';
        }
      }

      // If database lookup doesn't yield text, fall back to UPC numbers to query general listings
      final hasInfo = detectedTitle.isNotEmpty || detectedDescription.isNotEmpty;
      final String searchQuery = Uri.encodeComponent(hasInfo ? detectedDescription : upc);
      
      final isCanada = _selectedRegion == 'CA';

      setState(() {
        _productInfo = ProductInfo(
          title: hasInfo ? detectedTitle : 'Product (UPC: $upc)',
          description: hasInfo 
              ? 'Identified product description terms: "$detectedDescription". Below are live query results matching this exact or similar item text.'
              : 'No immediate database summary found. Searching matching platforms using the raw barcode index.',
          imageUrl: imageUrl,
        );

        if (isCanada) {
          _searchResults = [
            ProductResult(
              price: 'View exact matches',
              source: 'Google Shopping Canada',
              link: 'https://www.google.ca/search?tbm=shop&q=$searchQuery',
              icon: Icons.manage_search,
            ),
            ProductResult(
              price: 'Check warehouse stock',
              source: 'Costco Canada',
              link: 'https://www.costco.ca/CatalogSearch?keyword=$searchQuery',
              icon: Icons.card_membership,
            ),
            ProductResult(
              price: 'View discount offers',
              source: 'Giant Tiger',
              link: 'https://www.gianttiger.com/search?q=$searchQuery',
              icon: Icons.local_offer,
            ),
            ProductResult(
              price: 'View multi-packs',
              source: 'Dollarama',
              link: 'https://www.dollarama.com/en-CA/search?keyword=$searchQuery',
              icon: Icons.monetization_on,
            ),
            ProductResult(
              price: 'Check store availability',
              source: 'Walmart Canada',
              link: 'https://www.walmart.ca/search?q=$searchQuery',
              icon: Icons.store,
            ),
            ProductResult(
              price: 'Compare alternative vendors',
              source: 'ShopBot Canada',
              link: 'https://www.shopbot.ca/s?q=$searchQuery',
              icon: Icons.travel_explore,
            ),
            ProductResult(
              price: 'View merchant listings',
              source: 'Amazon.ca Marketplace',
              link: 'https://www.amazon.ca/s?k=$searchQuery',
              icon: Icons.shopping_bag,
            ),
            ProductResult(
              price: 'Check individual sellers',
              source: 'eBay Canada',
              link: 'https://www.ebay.ca/sch/i.html?_nkw=$searchQuery',
              icon: Icons.storefront,
            ),
          ];
        } else {
          _searchResults = [
            ProductResult(
              price: 'View exact matches',
              source: 'Google Shopping US',
              link: 'https://www.google.com/search?tbm=shop&q=$searchQuery',
              icon: Icons.manage_search,
            ),
            ProductResult(
              price: 'Check wholesale items',
              source: 'Costco Wholesale US',
              link: 'https://www.costco.com/CatalogSearch?keyword=$searchQuery',
              icon: Icons.card_membership,
            ),
            ProductResult(
              price: 'Check store deals',
              source: 'Walmart US Network',
              link: 'https://www.walmart.com/search?q=$searchQuery',
              icon: Icons.store,
            ),
            ProductResult(
              price: 'Compare web merchants',
              source: 'Yahoo Shopping Feed',
              link: 'https://shopping.yahoo.com/search?p=$searchQuery',
              icon: Icons.travel_explore,
            ),
            ProductResult(
              price: 'View current listings',
              source: 'Amazon.com',
              link: 'https://www.amazon.com/s?k=$searchQuery',
              icon: Icons.shopping_bag,
            ),
            ProductResult(
              price: 'Check marketplace listings',
              source: 'eBay US',
              link: 'https://www.ebay.com/sch/i.html?_nkw=$searchQuery',
              icon: Icons.storefront,
            ),
          ];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch the browser link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Region Selector Toggle
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.public, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Search Site Region:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SegmentedButton<String>(
                      segments: const <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'CA',
                          label: Text('Canada (🇨🇦)'),
                          icon: Icon(Icons.map),
                        ),
                        ButtonSegment<String>(
                          value: 'US',
                          label: Text('United States (🇺🇸)'),
                          icon: Icon(Icons.flag),
                        ),
                      ],
                      selected: <String>{_selectedRegion},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _selectedRegion = newSelection.first;
                        });
                        if (_scannedCode != null) {
                          _searchProduct(_scannedCode!);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan Barcode'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showManualEntryDialog,
                    icon: const Icon(Icons.keyboard),
                    label: const Text('Enter Manually'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              if (_productInfo != null) ...[
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _productInfo!.imageUrl.isNotEmpty
                              ? Image.network(
                                  _productInfo!.imageUrl,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 90,
                                    height: 90,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                  ),
                                )
                              : Container(
                                  width: 90,
                                  height: 90,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.shopping_basket, color: Colors.grey, size: 36),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _productInfo!.title,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _productInfo!.description,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Matching Vendor Feeds (${_selectedRegion == 'CA' ? 'Canada' : 'US'}):',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
              ],
              if (_searchResults.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final item = _searchResults[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade50,
                            child: Icon(
                              item.icon,
                              color: Colors.blue,
                            ),
                          ),
                          title: Text(
                            item.source,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text('Tap to open store results feed'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.price,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          onTap: () => _launchUrl(item.link),
                        ),
                      );
                    },
                  ),
                )
              else if (!_isLoading)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No active search results. Scan a barcode or enter a UPC code above to find the lowest price.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class BarcodeScannerScreen extends StatelessWidget {
  const BarcodeScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan UPC Code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  Navigator.pop(context, code);
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Center the barcode within the box',
                style: TextStyle(color: Colors.white, fontSize: 16, backgroundColor: Colors.black54),
              ),
            ),
          )
        ],
      ),
    );
  }
}
