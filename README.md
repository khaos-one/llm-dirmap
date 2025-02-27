# llm-dirmap

A Zig utility that generates a textual map of a directory structure and its file contents, designed to prepare context for large language models (LLMs). It includes configurable ignore patterns, text file extensions, and an estimated token count for AI processing.

## Features

- Recursively scans a specified directory and builds a tree-like output of its structure.
- Includes contents of text files based on extensions defined in `llm-dirmap.config`.
- Supports an ignore list to exclude files and directories (e.g., build artifacts, caches).
- Estimates the number of tokens required for an AI to process the output file (1 token ≈ 4 characters).
- Lightweight and written in Zig for performance and simplicity.

## Installation

### Prerequisites
- [Zig](https://ziglang.org/download/) (version 0.13.0 or later recommended).

### Building
1. Clone the repository:
   `git clone https://github.com/<your-username>/llm-dirmap.git`
   
   `cd llm-dirmap`
2. Build the executable:
   `zig build-exe src/main.zig -O ReleaseSafe`
   
   This generates an executable named `main`. Rename it to `llm-dirmap`:
   `mv main llm-dirmap`

### Optional: Install to System
To make `llm-dirmap` available system-wide:
   `sudo mv llm-dirmap /usr/local/bin/`

## Usage

Run the program with a directory path and an output file:
   `llm-dirmap <directory> <output_file>`

- `<directory>`: The directory to scan (e.g., `.` for current directory).
- `<output_file>`: The file where the directory map and contents will be written (e.g., `out.txt`).

### Example
   `llm-dirmap . out.txt`
   
This scans the current directory, applies rules from `llm-dirmap.config` (if present), and writes the result to `out.txt`.

## Configuration

The program reads a `llm-dirmap.config` file from the specified directory to configure ignore patterns and text file extensions. If `llm-dirmap.config` is absent, it processes all files and directories without filtering.

### `llm-dirmap.config` Format
Create a file named `llm-dirmap.config` in the target directory with the following structure:

```
[ignore]
# Files or directories to exclude
*.o
build/
temp/
.zig-cache/
zig-out/

[text_extensions]
# File extensions to include contents for
.txt
.md
.zig
```

- **`[ignore]`**: Lists patterns to exclude. Supports exact names (e.g., `build/`) and wildcard extensions (e.g., `*.o`). Directories should end with `/`.
- **`[text_extensions]`**: Lists extensions for files whose contents will be included in the output.

### Example Output (`out.txt`)
```
src/
  main.zig
Contents of ./src/main.zig:
[Contents of main.zig file here]

llm-dirmap.config
Contents of ./llm-dirmap.config:
[ignore]
*.o
build/
[...]

Estimated tokens for AI processing: 1234
```

## Token Estimation

The program estimates tokens needed for an AI to process the output file, assuming approximately 1 token equals 4 characters (including newlines). This is a rough heuristic suitable for many LLMs (e.g., GPT), though exact counts depend on the model’s tokenizer.

## Contributing

Contributions are welcome! Please:
1. Fork the repository.
2. Create a feature branch (`git checkout -b feature-name`).
3. Commit your changes (`git commit -m "Add feature"`).
4. Push to the branch (`git push origin feature-name`).
5. Open a pull request.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

## Acknowledgments

- Built with [Zig](https://ziglang.org/), a systems programming language focused on robustness and clarity.
- Designed to streamline directory context preparation for large language models.

---

### Instructions for Use
- Copy this text into your `README.md` file.
- Replace `<your-username>` with your actual GitHub username or repository path.
- If you’re using triple backticks for code blocks (e.g., `\`\`\`bash`), unescape them in your editor by removing the backslashes (e.g., `\`\`\`` → ```).
- Ensure the file names (`llm-dirmap`, `llm-dirmap.config`) match your renamed program and config in the code.

Let me know if you’d like further tweaks!