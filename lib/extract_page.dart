// filepath: lib/extract_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:share_handler/share_handler.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

class ExtractPage extends StatefulWidget {
  const ExtractPage({Key? key}) : super(key: key);

  @override
  State<ExtractPage> createState() => _ExtractPageState();
}

class _ExtractPageState extends State<ExtractPage> {
  final TextEditingController _controller = TextEditingController();
  String? _pickedFileName;
  String? _pickedFileBase64;
  bool _isLoading = false;
  SharedMedia? _sharedMedia;

  StreamSubscription? _sharedMediaStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadPromptFromAsset();
    _initShareHandler();
    //_handleInitialPdfIntent();
  }

void _initShareHandler() async {
    final handler = ShareHandlerPlatform.instance;

    // Get initial shared media (when app is launched by share)
    _sharedMedia = await handler.getInitialSharedMedia();
    if (_sharedMedia != null) {
      _processSharedMedia(_sharedMedia!);
    }

    // Listen for new shared media (when app is already running)
    _sharedMediaStreamSubscription = handler.sharedMediaStream.listen((SharedMedia media) {
      _processSharedMedia(media);
    });
  }

void _processSharedMedia(SharedMedia media) async {
    setState(() {
      _sharedMedia = media;
    });

    if (media.attachments != null && media.attachments!.isNotEmpty) {
      for (var attachment in media.attachments!) {
        if (attachment?.path != null) { 
          final String? attachmentPath = attachment?.path;

        print('Received attachment: ${attachment?.path}, type: ${attachment?.type}');

        // Check if it's a PDF
        if (attachment?.path != null && (attachment?.type == SharedAttachmentType.file)) {
          if (attachment?.path != null && attachmentPath!.toLowerCase().endsWith('.pdf')) {
            try {
              File sharedPdf = File(attachmentPath);
              if (await sharedPdf.exists()) {
                final appDocDir = await getApplicationDocumentsDirectory();
                final newFileName = 'shared_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
                final newFilePath = '${appDocDir.path}/$newFileName';

                await sharedPdf.copy(newFilePath);
                print('Successfully copied PDF to: $newFilePath');

                setState(() {
                  _pickedFileName = newFileName;
                  File newFile = File(newFilePath);
                  _pickedFileBase64 = base64Encode(newFile.readAsBytesSync());
                });

                print (_pickedFileBase64);
                await _onSubmit(); // Optionally, you can call _pickFile() to update the UI

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Received PDF: $newFileName')),
                );
                // Open/display PDF from newFilePath
              } else {
                print('Error: Shared PDF file does not exist at $attachmentPath');
              }
            } catch (e) {
              print('Error processing shared PDF with share_handler: $e');
            }
          }
        }
      }
      }
    } else if (media.content != null) {
      print('Received shared text: ${media.content}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Received Text: ${media.content}')),
      );
    }
  }

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