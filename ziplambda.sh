#!/bin/bash
#!/bin/bash

# Define Lambda source directories
LAMBDA_DIR="Lambda"
ZIP_DIR="./zipped_lambdas"

# Ensure the ZIP directory exists
mkdir -p "$ZIP_DIR"

# Find all Lambda Python files and zip them individually
for lambda_file in $(find "$LAMBDA_DIR" -name "*.py"); do
    # Extract the filename without extension
    filename=$(basename "$lambda_file" .py)
    zip_file="$ZIP_DIR/$filename.zip"
    
    echo "Zipping $lambda_file to $zip_file..."
    zip -j "$zip_file" "$lambda_file"
    
    echo "Created: $zip_file"
done

echo "All Lambda functions zipped successfully!"

