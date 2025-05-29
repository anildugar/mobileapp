import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart' show rootBundle;

//import 'package:permission_handler/permission_handler.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    MyHomePage(title: 'Home'),
    ExtractPage(),
    AccountingPage(),
  ];

  static const List<String> _titles = [
    'Home',
    'Extract',
    'Accounting',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_titles[_selectedIndex]),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.document_scanner),
            label: 'Extract',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'Accounting',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: _onItemTapped,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text('You have pushed the button this many times:'),
          Text(
            '$_counter',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          FloatingActionButton(
            onPressed: _incrementCounter,
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class ExtractPage extends StatefulWidget {
  const ExtractPage({super.key});

  @override
  State<ExtractPage> createState() => _ExtractPageState();
}

class _ExtractPageState extends State<ExtractPage> {
  final TextEditingController _controller = TextEditingController();
  String? _pickedFileName;
  String? _pickedFileBase64;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPromptFromAsset();
    //_handleInitialPdfIntent();
  }

  /*Future<void> _handleInitialPdfIntent() async {
    // Listen for incoming shared files (PDFs)
    _intentDataStreamSubscription = ReceiveSharingIntent.getMediaStream().listen((List<SharedMediaFile> value) async {
      if (value.isNotEmpty && value.first.path.toLowerCase().endsWith('.pdf')) {
        final file = File(value.first.path);
        final bytes = await file.readAsBytes();
        setState(() {
          _pickedFileName = file.path.split(Platform.pathSeparator).last;
          _pickedFileBase64 = base64Encode(bytes);
        });
        // Optionally, auto-submit after receiving the file:
        // await _onSubmit();
      }
    }, onError: (err) {
      // Handle error if needed
    });

    // For app launch with shared file
    final initialFiles = await ReceiveSharingIntent.getInitialMedia();
    if (initialFiles.isNotEmpty && initialFiles.first.path.toLowerCase().endsWith('.pdf')) {
      final file = File(initialFiles.first.path);
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedFileName = file.path.split(Platform.pathSeparator).last;
        _pickedFileBase64 = base64Encode(bytes);
      });
      // Optionally, auto-submit after receiving the file:
      // await _onSubmit();
    }
  }*/

  Future<void> _loadPromptFromAsset() async {
    final prompt = await rootBundle.loadString('assets/prompts/prompt.txt');
    setState(() {
      _controller.text = prompt;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_pickedFileBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a PDF file first.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyBgRhfGbYEduO7_RrPp3i1d3OEqbHblrU8",
    );

    final body = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text":
                  "Your role is an invoice validation and extraction system. First, determine if the attached PDF is a valid invoice. A valid invoice must clearly contain: Consignee (Ship to), Buyer/Seller (From/To) details, Invoice Number, Date, Motor Vehicle Number, itemized Goods with prices, and a Total amount. If the PDF is blurry, unreadable, or not an invoice at all, set `isValid` to `false` and `invoiceDetails` to `null` in your output. Provide a `confidence` score (0-1) for this validation."
            },
            {
              "text":
                  "If the invoice is valid, then extract the following details : From (Name, Address, GSTIN/UIN), To (Name, Address, GSTIN/UIN), Dispatch From, Ship To, Invoice No, e-Way Bill No, Invoice Date (Dated), Motor Vehicle No, GoodsDetails (S.N., Description, HSN Code, Qty, Unit, A.Qty, A.Unit, Packing, Price, CGST Rate, CGST Amount, SGST Rate, SGST Amount, Amount), CGST, SGST, Tcs, RoundOff, and Total amount."
            },
            {
              "inlineData": {
                "mimeType": "application/pdf",
                "data": _pickedFileBase64 ?? ""
              }
            }
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.0,
        "responseMimeType": "application/json"
      }
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      // Parse the response and extract only the required text
      final decoded = jsonDecode(response.body);
      String? extractedText;
      if (decoded['candidates'] != null &&
          decoded['candidates'] is List &&
          decoded['candidates'].isNotEmpty &&
          decoded['candidates'][0]['content'] != null &&
          decoded['candidates'][0]['content']['parts'] != null &&
          decoded['candidates'][0]['content']['parts'] is List &&
          decoded['candidates'][0]['content']['parts'].isNotEmpty &&
          decoded['candidates'][0]['content']['parts'][0]['text'] != null) {
        extractedText = decoded['candidates'][0]['content']['parts'][0]['text'];
      } else {
        extractedText = "No valid response found.";
      }

      setState(() {
        _controller.text = extractedText!;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _controller.text = "Error: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: [XTypeGroup(label: 'PDF', extensions: ['pdf'])],
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedFileName = file.name;
        _pickedFileBase64 = base64Encode(bytes);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _controller,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Enter your text here',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file),
                label: const Text('Pick a File'),
              ),
              if (_pickedFileName != null) ...[
                const SizedBox(height: 10),
                Text('Selected file: $_pickedFileName'),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _onSubmit,
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}

class AccountingPage extends StatelessWidget {
  const AccountingPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Manage your accounting here.',
        style: TextStyle(fontSize: 20),
      ),
    );
  }
}
