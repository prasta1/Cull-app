# Cull – Duplicate Photo Finder

A macOS application that intelligently identifies and removes duplicate photos from your computer using both cryptographic hashing and perceptual image analysis.

## Features

- **Intelligent Duplicate Detection**
  - SHA-256 cryptographic hashing for exact duplicates
  - Perceptual hashing to find visually similar images (same photo in different formats, compressions, or slight edits)

- **User-Friendly Interface**
  - Clean, modern SwiftUI design
  - Split-view comparison of suspected duplicates
  - Real-time scan progress with discovery and analysis counters
  - Preview thumbnails for visual comparison

- **Efficient Scanning**
  - Fast multi-threaded file discovery
  - Parallel hash computation
  - Photo metadata extraction (dimensions, file size, dates)

- **Safe Deletion**
  - Mark files for deletion before committing
  - View detailed information about each duplicate
  - Know exactly how much disk space you'll free

## Requirements

- macOS 13.0 or later
- Apple Silicon or Intel processor
- Xcode 15+ (for building from source)

## Architecture

### Core Components

**Models**
- `PhotoFile`: Represents a photo with metadata, hashes, and dimensions
- `DuplicateGroup`: Groups photos detected as duplicates
- `ScanSettings`: Configuration for scan operations

**Services**
- `DuplicateEngine`: Orchestrates the duplicate detection workflow
- `HashService`: Computes SHA-256 hashes for exact duplicate detection
- `PerceptualHashService`: Computes perceptual hashes for similar image detection

**Views & ViewModels**
- `ContentView`: Main application layout with split-view interface
- `ScanViewModel`: Manages scan state, progress, and user selections
- `ComparisonView`: Side-by-side display of duplicate images
- `DuplicateListView`: List of detected duplicate groups
- `FolderPickerView`: Folder selection interface

## Usage

1. Launch the application
2. Click "Select Folder" to choose a directory to scan
3. The app will discover all image files and compute hashes
4. Review duplicate groups in the left sidebar
5. Select photos you want to delete (they're marked with a trash icon)
6. Delete selected files

## Building

```bash
# Clone the repository
git clone https://github.com/prasta1/Cull-app.git
cd Cull-app

# Open in Xcode
open Cull.xcodeproj

# Build and run
⌘B to build
⌘R to run
```

## Supported Formats

The app scans for common image formats including:
- JPEG / JPG
- PNG
- HEIC / HEIF
- WebP
- GIF
- TIFF
- BMP

## Performance

- **Discovery Phase**: Rapid file system traversal to identify candidate images
- **Analysis Phase**: Parallel hash computation with progress tracking
- Typical scan of ~10,000 photos completes in under 2 minutes

## Safety Considerations

- Deleted files are moved to Trash (not permanently deleted)
- You can always recover deleted photos from your Trash
- Review duplicate groups carefully before committing deletions
- Metadata (creation/modification dates) is preserved in comparison view

## Future Enhancements

- Batch operations for multiple folders
- Advanced filtering and sorting options
- Duplicate elimination recommendations (keep highest quality)
- Export duplicate reports
- Cloud storage integration

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

This project is available under the MIT License.

---

**Cull** – Keep what matters, delete the rest.
