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
  Map<String, dynamic> _extractedData = {}; // Store extracted data here

  @override
  void initState() {
    super.initState();
    _loadPromptFromAsset();
    _initShareHandler();
  }

  void _initShareHandler() async {
    final handler = ShareHandlerPlatform.instance;

    _sharedMedia = await handler.getInitialSharedMedia();
    if (_sharedMedia != null) {
      await _processSharedMedia(_sharedMedia!);
    }

    _sharedMediaStreamSubscription = handler.sharedMediaStream.listen((SharedMedia media) async {
      await _processSharedMedia(media);
    });
  }

  Future<void> _processSharedMedia(SharedMedia media) async {
    setState(() {
      _sharedMedia = media;
    });

    if (media.attachments != null && media.attachments!.isNotEmpty) {
      for (var attachment in media.attachments!) {
        if (attachment?.path != null) {
          final String? attachmentPath = attachment?.path;

          print('Received attachment: ${attachment?.path}, type: ${attachment?.type}');

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

                  print(_pickedFileBase64);
                  await _onSubmit();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Received PDF: $newFileName')),
                  );
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
    _sharedMediaStreamSubscription?.cancel();
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
                  """ If the invoice is valid, extract the following details and **standardize the key names as specified below**:

**From** (object with keys: Name, Address, GSTIN/UIN)
**To** (object with keys: Name, Address, GSTIN/UIN)
**DispatchFrom** (string)
**ShipTo** (string)
**InvoiceNo** (string)
**e-WayBillNo** (string)
**InvoiceDate** (string, extracted from 'Dated')
**MotorVehicleNo** (string)
**GoodsDetails** (array of objects, each with the following standardized keys):
  * **SN** (number, for 'S.N.')
  * **Description** (string)
  * **HSNCode** (string, for 'HSN Code')
  * **Quantity** (number, for 'Qty')
  * **Unit** (string)
  * **ActualQuantity** (number, for 'A.Qty', or null if not present)
  * **ActualUnit** (string, for 'A.Unit', or null if not present)
  * **Packing** (string, or null if not present)
  * **PriceRate** (number, for 'Price', 'Rate', 'Price/Rate', or 'PRice/Rate')
  * **CGSTRate** (string, for 'CGST Rate', or null if not present)
  * **CGSTAmount** (number, for 'CGST Amount', or null if not present)
  * **SGSTRate** (string, for 'SGST Rate', or null if not present)
  * **SGSTAmount** (number, for 'SGST Amount', or null if not present)
  * **TotalItemAmount** (number, for 'Total' or 'Amount' of individual item)
**CGST** (number, or null if not present)
**SGST** (number, or null if not present)
**IGST** (number, or null if not present)
**TCS** (number, or null if not present)
**RoundOff** (number)
**TotalAmount** (number, for 'Total' or 'Total/Amount')"""
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

      final decoded = jsonDecode(response.body);
      String extractedText;
      if (decoded['candidates'] != null &&
          decoded['candidates'] is List &&
          decoded['candidates'].isNotEmpty &&
          decoded['candidates'][0]['content'] != null &&
          decoded['candidates'][0]['content']['parts'] != null &&
          decoded['candidates'][0]['content']['parts'] is List &&
          decoded['candidates'][0]['content']['parts'].isNotEmpty &&
          decoded['candidates'][0]['content']['parts'][0]['text'] != null) {
        extractedText = decoded['candidates'][0]['content']['parts'][0]['text'];
        // Parse the extracted text and update _extractedData
        _parseExtractedData(extractedText);
      } else {
        extractedText = "No valid response found.";
      }

      setState(() {
        _controller.text = extractedText;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _controller.text = "Error: $e";
        _isLoading = false;
      });
    }
  }

  // Helper function to parse the extracted data
  void _parseExtractedData(String extractedText) {
    try {
      // Assuming the extracted text is in JSON format
      Map<String, dynamic> parsedData = jsonDecode(extractedText);

      // Extract the extracted_data part
      if (parsedData.containsKey('invoiceDetails')) {
        setState(() {
           print(parsedData['invoiceDetails']);
          _extractedData = parsedData['invoiceDetails'] as Map<String, dynamic>;
        });
      } else {
        print('Error: invoiceDetails key not found in JSON response');
      }
    } catch (e) {
      print('Error parsing extracted data: $e');
      // Handle the error appropriately (e.g., show an error message)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Invoice Details"),
      ),
      body: _extractedData.isNotEmpty
          ? InvoiceDetailsView(extractedData: _extractedData)
          : _buildLoadingOrEmptyView(),
    );
  }

  Widget _buildLoadingOrEmptyView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else {
      return const Center(child: Text("No invoice data to display."));
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
}

class InvoiceDetailsView extends StatelessWidget {
  final Map<String, dynamic> extractedData;

  const InvoiceDetailsView({Key? key, required this.extractedData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildSections(context),
        ),
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    List<Widget> sections = [];

    // Invoice Overview Section
    sections.add(_buildSectionHeader("Invoice Overview"));
    sections.add(_buildTextView(
        "Invoice No.", extractedData.containsKey("InvoiceNo") ? extractedData["InvoiceNo"] : "N/A",
        fontSize: 18, fontWeight: FontWeight.bold));
    sections.add(_buildTextView(
        "Invoice Date", extractedData.containsKey("InvoiceDate") ? extractedData["InvoiceDate"] : "N/A",
        fontSize: 16,fontWeight: FontWeight.bold));
    sections.add(_buildTextView(
        "e-Way Bill No.", extractedData.containsKey("e-WayBillNo") ? extractedData["e-WayBillNo"] : "N/A",
        fontSize: 16,fontWeight: FontWeight.bold, placeholder: "N/A"));

    // Seller Details Section
    sections.add(_buildSectionHeader("Seller Details"));
    // Access "From" object and its properties
    final from = extractedData['From'] as Map<String, dynamic>?;
    final fromName = from?['Name']?.toString() ?? "N/A";
    final fromAddress = from?['Address']?.toString() ?? "N/A";
    final fromGstin = from?['GSTIN/UIN']?.toString() ?? "N/A";

    sections.add(_buildTextView(
        "From", fromName,
        fontSize: 16, fontWeight: FontWeight.bold));
    sections.add(_buildTextView(
        "Address", fromAddress,
        fontSize: 14,fontWeight: FontWeight.bold, multiline: true));
    sections.add(_buildTextView(
        "GSTIN/UIN", fromGstin,
        fontSize: 14, fontWeight: FontWeight.bold));

    // Buyer Details Section
    sections.add(_buildSectionHeader("Buyer Details"));
    final to = extractedData['To'] as Map<String, dynamic>?;
    final toName = to?['Name']?.toString() ?? "N/A";
    final toAddress = to?['Address']?.toString() ?? "N/A";
    final toGstin = to?['GSTIN/UIN']?.toString() ?? "N/A";

    sections.add(_buildTextView(
        "To", toName,
        fontSize: 16, fontWeight: FontWeight.bold));
    sections.add(_buildTextView(
        "Address", toAddress,
        fontSize: 14,fontWeight: FontWeight.bold, multiline: true));
    sections.add(_buildTextView(
        "GSTIN/UIN", toGstin,
        fontSize: 14, fontWeight: FontWeight.bold));

    // Dispatch & Shipping Section
    sections.add(_buildSectionHeader("Dispatch & Shipping"));
    sections.add(_buildTextView(
        "Dispatch From", extractedData.containsKey("DispatchFrom") ? extractedData["DispatchFrom"] : "N/A",
        fontSize: 14,fontWeight: FontWeight.bold));
    sections.add(_buildTextView(
        "Ship To", extractedData.containsKey("ShipTo") ? extractedData["ShipTo"] : "N/A",
        fontSize: 14, fontWeight: FontWeight.bold));
    sections.add(_buildTextView(
        "Motor Vehicle No.", extractedData.containsKey("MotorVehicleNo") ? extractedData["MotorVehicleNo"] : "N/A",
        fontSize: 14, fontWeight: FontWeight.bold, placeholder: "N/A"));

    // Items Purchased Section
    sections.add(_buildSectionHeader("Items Purchased"));
    if (extractedData.containsKey("GoodsDetails") &&
        extractedData["GoodsDetails"] is List) {
      List<dynamic> items = extractedData["GoodsDetails"];
      sections.add(
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              margin: EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.containsKey("Description") ? item["Description"] : "N/A",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Qty: ${item.containsKey("Quantity") ? item["Quantity"] : "N/A"}",
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          "Rate: ${item.containsKey("PriceRate") ? item["PriceRate"] : "N/A"}",
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          "Amount: ${item.containsKey("TotalItemAmount") ? item["TotalItemAmount"] : "N/A"}",
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } else {
      sections.add(const Text("No items purchased data available."));
    }

    // Payment Summary Section
    sections.add(_buildSectionHeader("Payment Summary"));
    // Horizontal alignment for CGST and SGST
    sections.add(
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (extractedData.containsKey("CGST") &&
              extractedData["CGST"] != null &&
              extractedData["CGST"] != "N/A")
            Expanded(
              child: _buildTextView(
                "CGST",
                extractedData["CGST"].toString(),
                fontSize: 16,
                placeholder: "N/A",
              ),
            ),
          SizedBox(width: 8), // Add some spacing between the fields
          if (extractedData.containsKey("SGST") &&
              extractedData["SGST"] != null &&
              extractedData["SGST"] != "N/A")
            Expanded(
              child: _buildTextView(
                "SGST",
                extractedData["SGST"].toString(),
                fontSize: 16,
                placeholder: "N/A",
              ),
            ),
        ],
      ),
    );

    // Horizontal alignment for TCS and RoundOff
    sections.add(
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (extractedData.containsKey("TCS") &&
              extractedData["TCS"] != null &&
              extractedData["TCS"] != "N/A")
            Expanded(
              child: _buildTextView(
                "TCS",
                extractedData["TCS"].toString(),
                fontSize: 16,
                placeholder: "N/A",
              ),
            ),
          SizedBox(width: 8), // Add some spacing between the fields
          if (extractedData.containsKey("RoundOff") &&
              extractedData["RoundOff"] != null &&
              extractedData["RoundOff"] != "N/A")
            Expanded(
              child: _buildTextView(
                "Round Off",
                extractedData["RoundOff"].toString(),
                fontSize: 16,
              ),
            ),
        ],
      ),
    );

    // Center alignment for Total Amount
    sections.add(
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTextView(
            "Total Amount",
            extractedData.containsKey("TotalAmount")
                ? extractedData["TotalAmount"]
                : "N/A",
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ],
      ),
    );

    return sections;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextView(String label, dynamic value,
      {double fontSize = 14,
      FontWeight? fontWeight,
      String? placeholder,
      Color? color,
      bool multiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
          ),
          Text(
            (value != null ? value.toString() : (placeholder ?? "N/A")),
            style: TextStyle(fontSize: fontSize, color: color),
            maxLines: multiline ? null : 1,
          ),
        ],
      ),
    );
  }
}