import os
import json
import argparse
import logging
from tqdm import tqdm
import chardet

def parse_arguments():
    parser = argparse.ArgumentParser(description="Export source code files to JSON.")
    parser.add_argument('folder_path', help='Path to the source code folder')
    parser.add_argument('-e', '--exclude-dirs', nargs='*', default=['node_modules'],
                        help='Directories to exclude (default: node_modules)')
    parser.add_argument('-x', '--exclude-files', nargs='*', default=['interface.cairo', 'test.cairo'],
                        help='Filenames to exclude (e.g., interface.cairo test.cairo)')
    parser.add_argument('-f', '--extensions', nargs='*', default=['.cairo', '.sol'],
                        help='File extensions to include (default: .cairo .sol)')
    parser.add_argument('-o', '--output', default='source_files.json',
                        help='Output JSON file path (default: source_files.json)')
    return parser.parse_args()

def export_source_code(folder_path, excluded_dirs, excluded_files, extensions):
    source_files = []
    for root, dirs, files in tqdm(os.walk(folder_path), desc="Scanning directories"):
        # Exclude specified directories and hidden directories
        dirs[:] = [d for d in dirs if d not in excluded_dirs and not d.startswith('.')]
        for filename in files:
            if (any(filename.endswith(ext) for ext in extensions) and
                not filename.startswith('.') and
                filename not in excluded_files):
                filepath = os.path.join(root, filename)
                if not os.access(filepath, os.R_OK):
                    logging.warning(f"File not readable: {filepath}")
                    continue
                try:
                    with open(filepath, 'rb') as f:
                        raw_data = f.read()
                        result = chardet.detect(raw_data)
                        encoding = result['encoding'] if result['encoding'] else 'utf-8'
                        content = raw_data.decode(encoding)
                    relative_path = os.path.relpath(filepath, folder_path)
                    source_files.append({'path': relative_path, 'content': content})
                except Exception as e:
                    logging.error(f"Could not read file {filepath}: {e}")
    return source_files

def main():
    args = parse_arguments()
    logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

    logging.info(f"Starting export from folder: {args.folder_path}")
    logging.info(f"Excluded directories: {args.exclude_dirs}")
    logging.info(f"Excluded filenames: {args.exclude_files}")
    logging.info(f"Included extensions: {args.extensions}")
    source_files = export_source_code(args.folder_path, set(args.exclude_dirs), set(args.exclude_files), args.extensions)
    
    try:
        with open(args.output, 'w', encoding='utf-8') as json_file:
            json.dump(source_files, json_file, indent=2)
        logging.info(f"Source files exported to {args.output}")
    except Exception as e:
        logging.error(f"Failed to write JSON output: {e}")

if __name__ == "__main__":
    main()
