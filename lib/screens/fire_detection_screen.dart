import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/camera_service.dart';
import '../services/fire_detection_service.dart';

class FireDetectionScreen extends StatefulWidget {
  const FireDetectionScreen({Key? key}) : super(key: key);

  @override
  State<FireDetectionScreen> createState() => _FireDetectionScreenState();
}

class _FireDetectionScreenState extends State<FireDetectionScreen> with TickerProviderStateMixin {
  final CameraService _cameraService = CameraService();
  final FireDetectionService _fireService = FireDetectionService();
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isLoading = true;
  bool _isDetecting = false;
  FireDetectionResult? _lastResult;
  String? _errorMessage;
  File? _selectedImage;
  
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize scan animation
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Initialize camera and model
      await Future.wait([
        _cameraService.initialize(),
        _fireService.loadModel(),
      ]);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }
  
  Future<void> _captureAndDetect() async {
    if (_isDetecting || !_cameraService.isInitialized) return;
    
    setState(() {
      _isDetecting = true;
      _errorMessage = null;
    });
    
    // Start scan animation
    _scanAnimationController.forward();
    
    try {
      // Capture image
      final imageBytes = await _cameraService.captureImage();
      
      // Detect fire
      final result = await _fireService.detectFire(imageBytes);
      
      setState(() {
        _lastResult = result;
        _isDetecting = false;
      });
      
      // Reset scan animation
      _scanAnimationController.reset();
      
      // Show alert if fire is detected
      if (result.isFire) {
        _showFireAlert(result);
      }
    } catch (e) {
      setState(() {
        _isDetecting = false;
        _errorMessage = e.toString();
      });
      _scanAnimationController.reset();
    }
  }
  
  Future<void> _selectImageFromGallery() async {
    if (_isDetecting) return;
    
    setState(() {
      _isDetecting = true;
      _errorMessage = null;
    });
    
    try {
      // Pick image from gallery
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (pickedImage == null) {
        setState(() {
          _isDetecting = false;
        });
        return;
      }
      
      // Set selected image for display
      setState(() {
        _selectedImage = File(pickedImage.path);
      });
      
      // Read image bytes for detection
      final imageBytes = await pickedImage.readAsBytes();
      
      // Detect fire
      final result = await _fireService.detectFire(imageBytes);
      
      setState(() {
        _lastResult = result;
        _isDetecting = false;
      });
      
      // Show alert if fire is detected
      if (result.isFire) {
        _showFireAlert(result);
      }
    } catch (e) {
      setState(() {
        _isDetecting = false;
        _errorMessage = e.toString();
      });
    }
  }
  
  Future<void> _analyzeSelectedImage(List<int> imageBytes) async {
    if (_isDetecting) return;
    
    setState(() {
      _isDetecting = true;
      _errorMessage = null;
    });
    
    try {
      // Convert to Uint8List and detect fire in selected image
      final uint8List = Uint8List.fromList(imageBytes);
      final result = await _fireService.detectFire(uint8List);
      
      setState(() {
        _lastResult = result;
        _isDetecting = false;
      });
      
      // Show alert if fire is detected
      if (result.isFire) {
        _showFireAlert(result);
      }
    } catch (e) {
      setState(() {
        _isDetecting = false;
        _errorMessage = e.toString();
      });
    }
  }
  
  void _clearSelectedImage() {
    setState(() {
      _selectedImage = null;
      _lastResult = null;
    });
  }
  
  void _showFireAlert(FireDetectionResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[50],
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 32),
            const SizedBox(width: 8),
            const Text('🔥 FIRE DETECTED!', 
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confidence: ${result.confidencePercentage.toStringAsFixed(1)}%'),
            Text('Risk Level: ${result.riskLevel}'),
            const SizedBox(height: 16),
            const Text('Take immediate action if this is a real fire emergency!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // You could add emergency call functionality here
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Emergency', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _scanAnimationController.dispose();
    _cameraService.dispose();
    _fireService.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing Fire Detection...'),
            ],
          ),
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fire Detection')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_errorMessage'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeServices,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('🔥 Fire Detection'),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library, color: Colors.white),
            onPressed: _selectImageFromGallery,
            tooltip: 'Select from Gallery',
          ),
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: _cameraService.toggleFlash,
            tooltip: 'Toggle Flash',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview or Selected Image
          if (_selectedImage != null)
            Container(
              width: double.infinity,
              height: double.infinity,
              child: Image.file(
                _selectedImage!,
                fit: BoxFit.cover,
              ),
            )
          else if (_cameraService.isInitialized)
            CameraPreview(_cameraService.controller!)
          else
            const Center(child: Text('Camera not available')),
          
          // Clear Image Button (when image is selected)
          if (_selectedImage != null)
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: _clearSelectedImage,
                backgroundColor: Colors.black54,
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          
          // Detection Results Overlay
          if (_lastResult != null)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lastResult!.isFire ? Colors.red[100] : Colors.green[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _lastResult!.isFire ? Colors.red : Colors.green,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_lastResult!.isFire ? Colors.red : Colors.green).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _lastResult!.isFire ? Colors.red : Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _lastResult!.isFire ? Icons.local_fire_department : Icons.check_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _lastResult!.isFire ? 'FIRE DETECTED' : 'NO FIRE',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _lastResult!.isFire ? Colors.red : Colors.green,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Confidence: ${_lastResult!.confidencePercentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: (_lastResult!.isFire ? Colors.red : Colors.green).shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'Risk: ${_lastResult!.riskLevel}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: (_lastResult!.isFire ? Colors.red : Colors.green).shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          
          // Scanning animation overlay
          if (_isDetecting)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _scanAnimation,
                builder: (context, child) {
                  return Container(
                    color: Colors.black.withOpacity(0.3),
                    child: CustomPaint(
                      painter: ScanLinePainter(_scanAnimation.value),
                      size: Size.infinite,
                    ),
                  );
                },
              ),
            ),
          
          // Scanning animation overlay
          if (_isDetecting)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _scanAnimation,
                builder: (context, child) {
                  return Container(
                    color: Colors.black.withOpacity(0.3),
                    child: CustomPaint(
                      painter: ScanLinePainter(_scanAnimation.value),
                      size: Size.infinite,
                    ),
                  );
                },
              ),
            ),
          
          if (_errorMessage != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  'Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedImage == null 
        ? Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: FloatingActionButton.large(
              onPressed: _isDetecting ? null : _captureAndDetect,
              backgroundColor: _isDetecting ? Colors.grey : Colors.orange,
              child: _isDetecting 
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                  : const Icon(Icons.camera_alt, size: 32, color: Colors.white),
            ),
          )
        : Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: _isDetecting ? null : () async {
                if (_selectedImage != null) {
                  final bytes = await _selectedImage!.readAsBytes();
                  _analyzeSelectedImage(bytes);
                }
              },
              backgroundColor: _isDetecting ? Colors.grey : Colors.orange,
              icon: _isDetecting 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                  : const Icon(Icons.search, color: Colors.white),
              label: Text(
                _isDetecting ? 'Analyzing...' : 'Analyze Image',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class ScanLinePainter extends CustomPainter {
  final double progress;
  
  ScanLinePainter(this.progress);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    final glowPaint = Paint()
      ..color = Colors.orange.withOpacity(0.3)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    
    final y = size.height * progress;
    
    // Draw glow effect
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      glowPaint,
    );
    
    // Draw scan line
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
