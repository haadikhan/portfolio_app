import "dart:typed_data";

import "package:file_saver/file_saver.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:open_filex/open_filex.dart";
import "package:printing/printing.dart";

import "../../../core/i18n/app_translations.dart";

/// Full-screen PDF preview — one page per screen, vertical continuous scroll,
/// zoom fills the viewport, +/- buttons scale around the viewport center.
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

  final ScrollController _scrollController = ScrollController();
  final Map<int, TransformationController> _zoomControllers = {};

  double _currentScale = 1.0;

  /// Actual body size populated by [LayoutBuilder]; used for zoom-around-center.
  Size _viewportSize = Size.zero;

  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;
  static const double _zoomStep = 0.5;

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
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final pages = _pages;
    if (pages == null || !mounted || _viewportSize.height <= 0) return;
    final page = (_scrollController.offset / _viewportSize.height)
        .round()
        .clamp(0, pages.length - 1);
    if (_currentPage != page) {
      setState(() {
        _currentPage = page;
        _currentScale =
            _zoomControllers[page]?.value.getMaxScaleOnAxis() ?? 1.0;
      });
    }
  }

  Future<void> _loadPages() async {
    try {
      final pages = <PdfRaster>[];
      await for (final page in Printing.raster(widget.bytes, dpi: 220)) {
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

  TransformationController _controllerFor(int index) {
    return _zoomControllers.putIfAbsent(index, () {
      final controller = TransformationController();
      controller.addListener(() {
        final scale = controller.value.getMaxScaleOnAxis();
        if (mounted &&
            index == _currentPage &&
            (scale - _currentScale).abs() > 0.01) {
          setState(() => _currentScale = scale);
        }
      });
      return controller;
    });
  }

  /// Applies [newScale] to [controller] while keeping the viewport center
  /// fixed (i.e. the image zooms inward/outward from the center of the screen).
  void _scaleAroundCenter(TransformationController controller, double newScale) {
    final w = _viewportSize.width;
    final h = _viewportSize.height;
    if (w <= 0 || h <= 0) return;

    final currentScale = controller.value.getMaxScaleOnAxis();
    final currentTx = controller.value.entry(0, 3);
    final currentTy = controller.value.entry(1, 3);

    // Convert viewport center to child-space focal point.
    final focalX = (w / 2 - currentTx) / currentScale;
    final focalY = (h / 2 - currentTy) / currentScale;

    // New translation so focal point stays at viewport center.
    final newTx = w / 2 - focalX * newScale;
    final newTy = h / 2 - focalY * newScale;

    controller.value = Matrix4.identity()
      ..translate(newTx, newTy)
      ..scale(newScale, newScale);
  }

  void _zoomIn() {
    final controller = _controllerFor(_currentPage);
    final current = controller.value.getMaxScaleOnAxis();
    final next = (current + _zoomStep).clamp(_minScale, _maxScale);
    _scaleAroundCenter(controller, next);
  }

  void _zoomOut() {
    final controller = _controllerFor(_currentPage);
    final current = controller.value.getMaxScaleOnAxis();
    final next = (current - _zoomStep).clamp(_minScale, _maxScale);
    if (next <= _minScale) {
      controller.value = Matrix4.identity();
      if (mounted) setState(() => _currentScale = 1.0);
    } else {
      _scaleAroundCenter(controller, next);
    }
  }

  void _resetZoom() {
    _zoomControllers[_currentPage]?.value = Matrix4.identity();
    if (mounted) setState(() => _currentScale = 1.0);
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

      if (!kIsWeb) {
        try {
          final savedPath = await FileSaver.instance.saveFile(
            name: base,
            bytes: bytes,
            fileExtension: "pdf",
            mimeType: MimeType.pdf,
          );

          if (savedPath.isNotEmpty) {
            final result = await OpenFilex.open(savedPath);

            if (result.type == ResultType.done) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Report saved and opened"),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              return;
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Saved to: $savedPath\n"
                    "Open with a PDF viewer.",
                  ),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            return;
          }
        } catch (e, st) {
          debugPrint("[report_preview] saveFile+open failed: $e\n$st");
        }
      }

      try {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
        return;
      } catch (e, st) {
        debugPrint("[report_preview] sharePdf fallback failed: $e\n$st");
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
          : LayoutBuilder(
              builder: (context, constraints) {
                // Capture the real body size every build.
                _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                final vw = _viewportSize.width;
                final vh = _viewportSize.height;

                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      // Lock outer scroll when zoomed in so the user can pan.
                      physics: _currentScale > 1.05
                          ? const NeverScrollableScrollPhysics()
                          : const ClampingScrollPhysics(),
                      itemCount: _pages!.length,
                      itemBuilder: (context, index) {
                        final raster = _pages![index];
                        // Each page occupies exactly one viewport-height slot.
                        return SizedBox(
                          width: vw,
                          height: vh,
                          child: FutureBuilder<Uint8List>(
                            future: raster.toPng(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              return InteractiveViewer(
                                transformationController:
                                    _controllerFor(index),
                                minScale: _minScale,
                                maxScale: _maxScale,
                                panEnabled: true,
                                scaleEnabled: true,
                                onInteractionEnd: (_) {
                                  final scale = _controllerFor(index)
                                      .value
                                      .getMaxScaleOnAxis();
                                  if (scale < _minScale + 0.05) {
                                    _zoomControllers[index]?.value =
                                        Matrix4.identity();
                                  }
                                },
                                // Child matches the viewport so BoxFit.contain
                                // fills the maximum available screen space.
                                child: SizedBox(
                                  width: vw,
                                  height: vh,
                                  child: Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    gaplessPlayback: true,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),

                    // ── Page counter ────────────────────────────────────
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

                    // ── Zoom bar ─────────────────────────────────────────
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
                                    ? _resetZoom
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
