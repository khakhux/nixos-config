#!/usr/bin/env bash
# Test script to verify SOPS encryption/decryption with git filters

set -e  # Exit on error

echo "===== SOPS Git Filter Test Script ====="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if required tools are available
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}✗ $1 is not installed${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ $1 is available${NC}"
    fi
}

echo "Checking required tools..."
check_tool sops
check_tool age
check_tool git
echo ""

# Check if age key exists
AGE_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
if [ ! -f "$AGE_KEY_FILE" ]; then
    echo -e "${RED}✗ Age key not found at $AGE_KEY_FILE${NC}"
    echo "Please run 'home-manager switch' first to generate the age key"
    exit 1
else
    echo -e "${GREEN}✓ Age key exists at $AGE_KEY_FILE${NC}"
    echo "Public key:"
    age-keygen -y "$AGE_KEY_FILE"
fi
echo ""

# Check if SOPS_AGE_KEY_FILE is set
if [ -z "$SOPS_AGE_KEY_FILE" ]; then
    echo -e "${YELLOW}⚠ SOPS_AGE_KEY_FILE environment variable not set${NC}"
    echo "Setting it manually for this test..."
    export SOPS_AGE_KEY_FILE="$AGE_KEY_FILE"
else
    echo -e "${GREEN}✓ SOPS_AGE_KEY_FILE is set to: $SOPS_AGE_KEY_FILE${NC}"
fi
echo ""

# Create a temporary test directory
TEST_DIR=$(mktemp -d)
echo "Created test directory: $TEST_DIR"
cd "$TEST_DIR"

# Initialize git repository
echo "Initializing git repository..."
git init
git config user.name "SOPS Test"
git config user.email "test@example.com"
echo ""

# Create a test properties file with sensitive data
echo "Creating test.properties with sensitive data..."
cat > test.properties << 'EOF'
clear=texto_claro
secret_enc=SuperSecretPassword123!
EOF

echo "Original content of test.properties:"
cat test.properties
echo ""

# Add and commit the file (this should trigger encryption)
echo "Adding and committing test.properties (should be encrypted)..."
git add test.properties
git commit -m "Add encrypted properties file"
echo ""

# Check if the file is encrypted in git
echo "Checking if file is encrypted in git..."
COMMITTED_CONTENT=$(git show HEAD:test.properties)
if echo "$COMMITTED_CONTENT" | grep -q "sops_"; then
    echo -e "${GREEN}✓ File is encrypted in git (contains 'sops_' marker)${NC}"
    echo "First few lines of encrypted content:"
    echo "$COMMITTED_CONTENT" | head -n 10
else
    echo -e "${RED}✗ File does not appear to be encrypted${NC}"
    echo "Content:"
    echo "$COMMITTED_CONTENT"
    exit 1
fi
echo ""

# Check if the working copy is decrypted
echo "Checking if working copy is decrypted..."
if grep -q "SuperSecretPassword123!" test.properties; then
    echo -e "${GREEN}✓ Working copy is decrypted (contains original password)${NC}"
else
    echo -e "${RED}✗ Working copy is not properly decrypted${NC}"
    cat test.properties
    exit 1
fi
echo ""

# Test git diff (should show decrypted content)
echo "Modifying file and testing git diff..."
echo "new_field_enc=new-value" >> test.properties
git add test.properties

echo "Git diff should show decrypted content:"
if git diff --cached | grep -q "new_field_enc=new-value"; then
    echo -e "${GREEN}✓ Git diff shows decrypted content${NC}"
else
    echo -e "${RED}✗ Git diff does not show expected content${NC}"
    git diff --cached
    exit 1
fi
echo ""

# Clean up
cd /
rm -rf "$TEST_DIR"
echo "Cleaned up test directory"
echo ""

echo -e "${GREEN}===== All tests passed! =====${NC}"
echo ""
echo "Summary:"
echo "- SOPS and age are properly installed"
echo "- Age key is generated and accessible"
echo "- Git filters are configured correctly"
echo "- Files are encrypted on commit"
echo "- Files are decrypted in working directory"
echo "- Git diff shows decrypted content"
echo ""
echo "Next steps:"
echo "1. Update .sops.yaml files in your repositories with your age public key:"
echo "   $AGE_PUBLIC_KEY"
echo "2. Ensure .gitattributes and firma-git-config are in your repositories"
echo "3. Test with actual project repositories"
