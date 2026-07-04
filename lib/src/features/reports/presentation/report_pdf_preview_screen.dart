import "dart:typed_data";

import "package:file_saver/file_saver.dart";
import "package:flutter/foundation.dart"
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import "package:flutter/material.dart";
import "package:printing/printing.dart";

import "../../../core/i18n/app_translations.dart";

/// Full-screen PDF preview with explicit **Download** and **Print** in the app bar.
class ReportPdfPreviewScreen extends StatefulWidget {
  const ReportPdfPreviewScreen({
    super.key,
    required this.bytes,
    required this.fileName,
    this.title,
  });

  final Uint8List bytes;
  final String fileName;
  final String? title;

  @override
  State<ReportPdfPreviewScreen> createState() => _ReportPdfPreviewScreenState();
}

class _ReportPdfPreviewScreenState extends State<ReportPdfPreviewScreen> {
  bool _isDownloading = false;

  List<PdfRaster>? _pages;
  int _currentPage = 0;
  bool _isLoadingPages = true;
  String? _loadError;
  final PageController _pageController = PageController();
  final Map<int, TransformationController> _zoomControllers = {};
  double _currentScale = 1.0;
  double _fitWidthScale = 1.0;
  static const double _zoomStep = 0.5;
  static const double _minScale = 0.5;
  static const double _maxScale = 5.0;

  String get _baseName {
    final n = widget.fileName.trim();
    if (n.toLowerCase().endsWith(".pdf")) {
      return n.substring(0, n.length - 4);
    }
    return n.isEmpty ? "report" : n;
  }

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    try {
      final pages = <PdfRaster>[];
      await for (final page in Printing.raster(
        widget.bytes,
        dpi: 220,
      )) {
        pages.add(page);
      }
      if (mounted) {
        setState(() {
          _pages = pages;
          _isLoadingPages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoadingPages = false;
        });
      }
    }
  }

  Matrix4 _fitWidthMatrix(BuildContext context, int pageIndex) {
    final screenWidth = MediaQuery.of(context).size.width;

    final page = _pages![pageIndex];
    final imageWidth = page.width.toDouble();

    final scaleX = screenWidth / imageWidth;

    final scale = scaleX;

    if (scale <= 1.0) {
      return Matrix4.identity();
    }

    return Matrix4.identity()..scaleByDouble(scale, scale, scale, 1.0);
  }

  TransformationController _controllerFor(int index) {
    return _zoomControllers.putIfAbsent(index, () {
      final controller = TransformationController();
      controller.addListener(() {
        final scale = controller.value.getMaxScaleOnAxis();
        if (mounted && (scale - _currentScale).abs() > 0.01) {
          setState(() => _currentScale = scale);
        }
      });
      return controller;
    });
  }

  void _zoomIn() {
    final controller = _zoomControllers[_currentPage];
    if (controller == null) return;
    final current = controller.value.getMaxScaleOnAxis();
    final next = (current + _zoomStep).clamp(_minScale, _maxScale);
    final matrix = Matrix4.identity()..scaleByDouble(next, next, next, 1.0);
    controller.value = matrix;
  }

  void _zoomOut() {
    final controller = _zoomControllers[_currentPage];
    if (controller == null) return;
    final current = controller.value.getMaxScaleOnAxis();
    final next = (current - _zoomStep).clamp(_minScale, _maxScale);
    if (next <= _minScale) {
      controller.value = Matrix4.identity();
    } else {
      final matrix = Matrix4.identity()..scaleByDouble(next, next, next, 1.0);
      controller.value = matrix;
    }
  }

  void _resetZoom(int index) {
    if (!mounted || _pages == null) return;
    final fitMatrix = _fitWidthMatrix(context, index);
    _zoomControllers[index]?.value = fitMatrix;
    if (mounted) {
      setState(() {
        _currentScale = fitMatrix.getMaxScaleOnAxis();
        _fitWidthScale = _currentScale;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _zoomControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final bytes = widget.bytes;
      final fileName = widget.fileName;
      final base = _baseName;

      Future<bool> trySharePdf() async {
        try {
          await Printing.sharePdf(bytes: bytes, filename: fileName);
          return true;
        } catch (e, st) {
          debugPrint("[report_preview] sharePdf failed: $e\n$st");
          return false;
        }
      }

      Future<bool> tryFileSaver() async {
        try {
          await FileSaver.instance.saveFile(
            name: base,
            bytes: bytes,
            fileExtension: "pdf",
            mimeType: MimeType.pdf,
          );
          return true;
        } catch (e, st) {
          debugPrint("[report_preview] FileSaver.saveFile failed: $e\n$st");
          return false;
        }
      }

      final preferShareFirst =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      if (preferShareFirst) {
        if (await trySharePdf()) return;
        if (await tryFileSaver()) return;
      } else {
        if (await tryFileSaver()) return;
        if (await trySharePdf()) return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr("reports_pdf_failed"))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _print() async {
    await Printing.layoutPdf(
      onLayout: (_) async => widget.bytes,
      name: widget.fileName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? context.tr("reports_view_title")),
        actions: [
          IconButton(
            tooltip: context.tr("reports_download_action"),
            onPressed: _isDownloading ? null : _download,
            icon: _isDownloading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: context.tr("reports_print"),
            icon: const Icon(Icons.print_outlined),
            onPressed: _print,
          ),
        ],
      ),
      body: _isLoadingPages
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Unable to load PDF: $_loadError",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : (_pages == null || _pages!.isEmpty)
          ? const Center(child: Text("No pages to display"))
          : Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: _pages!.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                      _currentScale = _zoomControllers[index]
                              ?.value.getMaxScaleOnAxis() ??
                          1.0;
                      _fitWidthScale =
                          _fitWidthMatrix(context, index).getMaxScaleOnAxis();
                    });
                  },
                  physics: _currentScale > (_fitWidthScale + 0.05)
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemBuilder: (context, index) {
                    final raster = _pages![index];
                    return FutureBuilder<Uint8List>(
                      future: raster.toPng(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final controller = _zoomControllers[index];
                          if (controller != null &&
                              controller.value == Matrix4.identity() &&
                              _pages != null) {
                            final fitMatrix =
                                _fitWidthMatrix(context, index);
                            if (fitMatrix != Matrix4.identity()) {
                              controller.value = fitMatrix;
                              final fitScale = fitMatrix.getMaxScaleOnAxis();
                              if (mounted && index == _currentPage) {
                                setState(() {
                                  _currentScale = fitScale;
                                  _fitWidthScale = fitScale;
                                });
                              }
                            }
                          }
                        });
                        return InteractiveViewer(
                          transformationController: _controllerFor(index),
                          minScale: _minScale,
                          maxScale: _maxScale,
                          panEnabled: true,
                          scaleEnabled: true,
                          onInteractionEnd: (details) {
                            final scale = _controllerFor(index)
                                .value
                                .getMaxScaleOnAxis();
                            if (scale < 0.55) {
                              _resetZoom(index);
                            }
                          },
                          child: Center(
                            child: Image.memory(
                              snapshot.data!,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              gaplessPlayback: true,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                if (_pages!.length > 1)
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Page ${_currentPage + 1} of ${_pages!.length}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_pages!.length > 1 && _currentPage > 0)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _NavButton(
                        icon: Icons.chevron_left,
                        onTap: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                      ),
                    ),
                  ),
                if (_pages!.length > 1 &&
                    _currentPage < _pages!.length - 1)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _NavButton(
                        icon: Icons.chevron_right,
                        onTap: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove,
                              color: Colors.white,
                            ),
                            tooltip: "Zoom out",
                            onPressed: _currentScale > _minScale
                                ? _zoomOut
                                : null,
                          ),
                          Container(
                            width: 56,
                            alignment: Alignment.center,
                            child: Text(
                              "${(_currentScale * 100).round()}%",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                            ),
                            tooltip: "Zoom in",
                            onPressed: _currentScale < _maxScale
                                ? _zoomIn
                                : null,
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: Colors.white24,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.zoom_out_map,
                              color: Colors.white,
                            ),
                            tooltip: "Reset zoom",
                            onPressed: _currentScale > _minScale
                                ? () => _resetZoom(_currentPage)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
