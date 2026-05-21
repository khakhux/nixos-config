#!/usr/bin/env bash
# Test script to verify SOPS encryption/decryption with git filters

set -e

echo "===== SOPS Git Filter Test Script ====="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

if [ -z "${SOPS_AGE_KEY_FILE:-}" ]; then
  echo -e "${YELLOW}⚠ SOPS_AGE_KEY_FILE environment variable not set${NC}"
  echo "Setting it manually for this test..."
  export SOPS_AGE_KEY_FILE="$AGE_KEY_FILE"
else
  echo -e "${GREEN}✓ SOPS_AGE_KEY_FILE is set to: $SOPS_AGE_KEY_FILE${NC}"
fi
echo ""

TEST_DIR=$(mktemp -d)
echo "Created test directory: $TEST_DIR"
cd "$TEST_DIR"

echo "Initializing git repository..."
git init
git config user.name "SOPS Test"
git config user.email "test@example.com"
echo ""

echo "Creating test.yml with sensitive data..."
cat > test.yml << 'EOF'
clear: texto_claro
secret_enc: SuperSecretPassword123!
EOF

echo "Original content of test.yml:"
cat test.yml
echo ""

echo "Adding and committing test.yml (should be encrypted)..."
git add test.yml
git commit -m "Add encrypted properties file"
echo ""

echo "Checking if file is encrypted in git..."
COMMITTED_CONTENT=$(git show HEAD:test.yml)
if echo "$COMMITTED_CONTENT" | grep -q "sops:"; then
  echo -e "${GREEN}✓ File is encrypted in git (contains 'sops:' marker)${NC}"
  echo "First few lines of encrypted content:"
  echo "$COMMITTED_CONTENT" | head -n 10
else
  echo -e "${RED}✗ File does not appear to be encrypted${NC}"
  echo "Content:"
  echo "$COMMITTED_CONTENT"
  exit 1
fi
echo ""

echo "Checking if working copy is decrypted..."
if grep -q "SuperSecretPassword123!" test.yml; then
  echo -e "${GREEN}✓ Working copy is decrypted (contains original password)${NC}"
else
  echo -e "${RED}✗ Working copy is not properly decrypted${NC}"
  cat test.yml
  exit 1
fi
echo ""

echo "Modifying file and testing git diff..."
echo "new_field_enc: new-value" >> test.yml
git add test.yml

echo "Git diff should show decrypted content:"
if git diff --cached | grep -q "new_field_enc: new-value"; then
  echo -e "${GREEN}✓ Git diff shows decrypted content${NC}"
else
  echo -e "${RED}✗ Git diff does not show expected content${NC}"
  git diff --cached
  exit 1
fi
echo ""

cd /
rm -rf "$TEST_DIR"
echo "Cleaned up test directory"
echo ""

echo -e "${GREEN}===== All tests passed! =====${NC}"