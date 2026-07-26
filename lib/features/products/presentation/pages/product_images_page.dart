import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../../database/app_database.dart';
import '../../../../database/database_dao.dart';

/// Page for viewing and managing product images.
///
/// Displays a grid of images associated with a product. Supports setting
/// a primary image, deleting images, and viewing images in full screen.
///
/// ## Image Management
/// - **Grid View**: All images displayed in a responsive grid layout.
/// - **Primary Indicator**: The primary image is marked with a star badge.
/// - **Add Image**: Placeholder button (file_picker not available in this context).
/// - **Delete**: Long-press or use the menu to delete an image.
/// - **Full Screen**: Tap any image to view it in full-screen mode.
///
/// ## Architecture
/// This page directly accesses the [DatabaseDao] for image CRUD operations,
/// bypassing the repository layer for simplicity. In a production app with
/// remote image upload, this would use a dedicated repository.
///
/// ## Usage
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => ProductImagesPage(
///     productId: 'prod-123',
///     productName: 'Widget',
///   ),
/// ));
/// ```
class ProductImagesPage extends StatefulWidget {
  /// The UUID of the product whose images to manage.
  final String productId;

  /// Display name shown in the app bar.
  final String productName;

  const ProductImagesPage({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<ProductImagesPage> createState() => _ProductImagesPageState();
}

class _ProductImagesPageState extends State<ProductImagesPage> {
  late final DatabaseDao _dao;
  List<ProductImage> _images = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _dao = GetIt.instance<DatabaseDao>();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _isLoading = true);
    try {
      final images = await _dao.getProductImages(widget.productId);
      if (mounted) {
        setState(() {
          _images = images;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteImage(ProductImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dao.deleteProductImage(image.id);
        await _loadImages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _setPrimaryImage(ProductImage image) async {
    try {
      // Update all images for this product to set isPrimary = false
      for (final img in _images) {
        if (img.isPrimary && img.id != image.id) {
          await _dao.insertProductImage(
            ProductImagesCompanion.insert(
              id: img.id,
              productId: img.productId,
              imageUrl: img.imageUrl,
              isPrimary: const Value(false),
              sortOrder: Value(img.sortOrder),
              createdAt: img.createdAt,
            ),
          );
        }
      }
      // Set the selected image as primary
      await _dao.insertProductImage(
        ProductImagesCompanion.insert(
          id: image.id,
          productId: image.productId,
          imageUrl: image.imageUrl,
          isPrimary: const Value(true),
          sortOrder: Value(image.sortOrder),
          createdAt: image.createdAt,
        ),
      );
      await _loadImages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Primary image updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set primary image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddImagePlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Image upload requires device file picker. Connect camera/gallery to add images.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _openFullScreenViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(
          images: _images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Images - ${widget.productName}'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadImages,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _images.isEmpty
              ? _buildEmptyState()
              : _buildImageGrid(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddImagePlaceholder,
        tooltip: 'Add Image',
        child: const Icon(Icons.add_photo_alternate),
      ),
    );
  }

  /// Builds the responsive grid of product images.
  Widget _buildImageGrid() {
    return RefreshIndicator(
      onRefresh: _loadImages,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final image = _images[index];
          return _buildImageCard(image, index);
        },
      ),
    );
  }

  /// Builds a single image card with primary indicator and actions.
  Widget _buildImageCard(ProductImage image, int index) {
    return GestureDetector(
      onTap: () => _openFullScreenViewer(index),
      onLongPress: () => _showImageActions(image),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image placeholder (since we can't load actual images without file_picker)
            _buildImagePlaceholder(image),
            // Primary badge
            if (image.isPrimary)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 12, color: Colors.white),
                      SizedBox(width: 2),
                      Text(
                        'Primary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Bottom gradient with actions
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Image ${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
                      onSelected: (value) => _handleMenuAction(value, image),
                      itemBuilder: (context) => [
                        if (!image.isPrimary)
                          const PopupMenuItem(
                            value: 'primary',
                            child: Text('Set as Primary'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a placeholder widget for images (since actual image loading
  /// requires network or file access).
  Widget _buildImagePlaceholder(ProductImage image) {
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            image.isPrimary ? 'Primary Image' : 'Product Image',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              image.imageUrl.length > 20
                  ? '${image.imageUrl.substring(0, 20)}...'
                  : image.imageUrl,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Shows the action sheet for an image (set primary, delete).
  void _showImageActions(ProductImage image) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_full),
              title: const Text('View Full Screen'),
              onTap: () {
                Navigator.pop(context);
                final index = _images.indexOf(image);
                if (index >= 0) _openFullScreenViewer(index);
              },
            ),
            if (!image.isPrimary)
              ListTile(
                leading: const Icon(Icons.star_border),
                title: const Text('Set as Primary'),
                onTap: () {
                  Navigator.pop(context);
                  _setPrimaryImage(image);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteImage(image);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Handles menu actions from the popup menu on each image card.
  void _handleMenuAction(String action, ProductImage image) {
    switch (action) {
      case 'primary':
        _setPrimaryImage(image);
        break;
      case 'delete':
        _deleteImage(image);
        break;
    }
  }

  /// Empty state when no images exist for the product.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No images yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add product images',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Full-screen image viewer with swipe navigation between images.
///
/// Displays images in a PageView allowing horizontal swiping. Includes
/// an image counter indicator and a close button.
class _FullScreenImageViewer extends StatefulWidget {
  final List<ProductImage> images;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          if (widget.images[_currentIndex].isPrimary)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.star, color: Colors.amber),
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final image = widget.images[index];
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 120,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  image.imageUrl,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (image.isPrimary)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PRIMARY IMAGE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
