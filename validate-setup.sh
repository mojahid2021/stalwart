#!/bin/bash
# ==============================================
# Stalwart Multi-Service Setup Validation Script
# ==============================================
# This script validates your setup before starting services
#
# Usage:
#   chmod +x validate-setup.sh
#   ./validate-setup.sh
# ==============================================

set -e

echo "🔍 Stalwart Multi-Service Setup Validation"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0

# Function to print colored output
error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
    ERRORS=$((ERRORS + 1))
}

warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
    WARNINGS=$((WARNINGS + 1))
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

info() {
    echo "ℹ️  $1"
}

# Check if Docker is installed
echo "1️⃣  Checking Docker installation..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    success "Docker is installed: $DOCKER_VERSION"
else
    error "Docker is not installed. Please install Docker first."
fi
echo ""

# Check if Docker Compose is installed
echo "2️⃣  Checking Docker Compose installation..."
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    success "Docker Compose is installed: $COMPOSE_VERSION"
elif command -v docker-compose &> /dev/null; then
    warning "You have the old docker-compose (standalone). Please upgrade to Docker Compose V2."
else
    error "Docker Compose is not installed. Please install Docker Compose first."
fi
echo ""

# Check if .env file exists
echo "3️⃣  Checking environment file..."
if [ -f ".env" ]; then
    success ".env file exists"
    
    # Check required variables
    REQUIRED_VARS=("ADMIN_SECRET" "DB_PASSWORD" "REDIS_PASSWORD" "MINIO_PASSWORD")
    for var in "${REQUIRED_VARS[@]}"; do
        if grep -q "^${var}=" .env; then
            VALUE=$(grep "^${var}=" .env | cut -d'=' -f2)
            if [[ "$VALUE" == *"CHANGE_ME"* ]] || [[ "$VALUE" == "" ]]; then
                error "$var is not set or uses a placeholder value"
            else
                success "$var is set"
            fi
        else
            error "$var is not defined in .env file"
        fi
    done
else
    error ".env file not found. Copy .env.example to .env and set your passwords."
    info "Run: cp .env.example .env && nano .env"
fi
echo ""

# Check if docker-compose.advanced.yml exists
echo "4️⃣  Checking docker-compose file..."
if [ -f "docker-compose.advanced.yml" ]; then
    success "docker-compose.advanced.yml exists"
    
    # Validate compose file syntax
    if docker compose -f docker-compose.advanced.yml config --quiet &> /dev/null; then
        success "docker-compose.advanced.yml syntax is valid"
    else
        error "docker-compose.advanced.yml has syntax errors"
        info "Run: docker compose -f docker-compose.advanced.yml config"
    fi
else
    error "docker-compose.advanced.yml not found"
fi
echo ""

# Check if config-advanced.toml exists
echo "5️⃣  Checking configuration file..."
if [ -f "config-advanced.toml" ]; then
    success "config-advanced.toml exists"
else
    warning "config-advanced.toml not found (optional)"
    info "If you want to use PostgreSQL+Redis+MinIO, you need this file"
fi
echo ""

# Check disk space
echo "6️⃣  Checking disk space..."
AVAILABLE_GB=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_GB" -gt 20 ]; then
    success "Available disk space: ${AVAILABLE_GB}GB"
else
    warning "Low disk space: ${AVAILABLE_GB}GB (recommended: 50GB+)"
fi
echo ""

# Check memory
echo "7️⃣  Checking available memory..."
if command -v free &> /dev/null; then
    TOTAL_MEM_GB=$(free -g | grep Mem | awk '{print $2}')
    if [ "$TOTAL_MEM_GB" -gt 4 ]; then
        success "Total memory: ${TOTAL_MEM_GB}GB"
    else
        warning "Low memory: ${TOTAL_MEM_GB}GB (recommended: 8GB+)"
    fi
else
    info "Memory check skipped (free command not available)"
fi
echo ""

# Check if ports are available
echo "8️⃣  Checking port availability..."
PORTS=(25 587 465 143 993 8080 443 9000 9001 5432 6379)
for port in "${PORTS[@]}"; do
    if command -v lsof &> /dev/null; then
        if lsof -Pi :$port -sTCP:LISTEN -t &> /dev/null; then
            warning "Port $port is already in use"
        else
            success "Port $port is available"
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            warning "Port $port is already in use"
        else
            success "Port $port is available"
        fi
    else
        info "Port check skipped (lsof/netstat not available)"
        break
    fi
done
echo ""

# Summary
echo "=========================================="
echo "📊 Validation Summary"
echo "=========================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    success "All checks passed! You're ready to start services."
    echo ""
    info "To start services, run:"
    echo "  docker compose -f docker-compose.advanced.yml up -d --build"
    echo ""
    info "To view logs, run:"
    echo "  docker compose -f docker-compose.advanced.yml logs -f"
    echo ""
    info "To access admin interface:"
    echo "  http://localhost:8080"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS warning(s) found. Review and proceed with caution.${NC}"
    echo ""
    info "You can still try to start services:"
    echo "  docker compose -f docker-compose.advanced.yml up -d --build"
else
    echo -e "${RED}❌ $ERRORS error(s) and $WARNINGS warning(s) found.${NC}"
    echo ""
    error "Please fix the errors before starting services."
    echo ""
    info "For help, see: MULTI_SERVICE_SETUP.md"
    exit 1
fi

echo ""
echo "📚 Documentation:"
echo "  - Quick Start: QUICKSTART.md"
echo "  - Multi-Service Setup: MULTI_SERVICE_SETUP.md"
echo "  - Complete Guide: SETUP.md"
echo ""
