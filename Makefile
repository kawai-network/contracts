# ==============================================================================
# Kawai Network Contracts Makefile
# ==============================================================================

.PHONY: help compile bindings update test test-gas coverage \
        gas-snapshot gas-compare deploy-local deploy-testnet deploy-vault \
        deploy-referral-testnet grant-minter-referral \
        deploy-cashback-testnet grant-minter-cashback \
        deploy-mining-testnet grant-minter-mining \
        verify clean abi-token abi-otcmarket abi-vault abi-revenue \
        abi-referral abi-cashback abi-mining abi-stablecoin

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
ABIS_DIR      := ./

# Foundry artifacts
TOKEN_ARTIFACT       := ./out/KawaiToken.sol/KawaiToken.json
OTCMARKET_ARTIFACT   := ./out/OTCMarket.sol/OTCMarket.json
VAULT_ARTIFACT       := ./out/PaymentVault.sol/PaymentVault.json
REVENUE_ARTIFACT     := ./out/RevenueDistributor.sol/RevenueDistributor.json
REFERRAL_ARTIFACT    := ./out/ReferralRewardDistributor.sol/ReferralRewardDistributor.json
CASHBACK_ARTIFACT    := ./out/DepositCashbackDistributor.sol/DepositCashbackDistributor.json
MINING_ARTIFACT      := ./out/MiningRewardDistributor.sol/MiningRewardDistributor.json
STABLECOIN_ARTIFACT  := ./out/MockStablecoin.sol/MockStablecoin.json

# Load environment variables from .env if exists
-include .env
export

# Deployment configuration (can be overridden via env vars or .env)
PRIVATE_KEY ?=
RPC_URL ?= https://testnet-rpc.monad.xyz
CONTRACT_ADDRESS ?=
ETHERSCAN_API_KEY ?=
CHAIN_ID ?= 10143

# ==============================================================================
# Help
# ==============================================================================
help:
	@echo "Kawai Network Contracts - Available Commands"
	@echo ""
	@echo "Build & Compile:"
	@echo "  make compile          Compile smart contracts with Foundry"
	@echo "  make bindings         Generate Go bindings from compiled contracts"
	@echo "  make update           Full update (compile + bindings)"
	@echo ""
	@echo "Testing:"
	@echo "  make test             Run contract tests"
	@echo "  make test-gas         Run tests with gas report"
	@echo "  make coverage         Generate test coverage report"
	@echo ""
	@echo "Gas Optimization:"
	@echo "  make gas-snapshot     Create gas usage baseline"
	@echo "  make gas-compare      Compare gas usage vs baseline"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy-local     Deploy to local Anvil"
	@echo "  make deploy-testnet   Deploy to Monad Testnet"
	@echo "  make deploy-vault     Deploy PaymentVault (mainnet/testnet)"
	@echo "  make deploy-referral-testnet  Deploy ReferralRewardDistributor"
	@echo "  make grant-minter-referral    Grant MINTER_ROLE to referral contract"
	@echo "  make deploy-cashback-testnet  Deploy DepositCashbackDistributor"
	@echo "  make grant-minter-cashback    Grant MINTER_ROLE to cashback contract"
	@echo "  make deploy-mining-testnet    Deploy MiningRewardDistributor"
	@echo "  make grant-minter-mining      Grant MINTER_ROLE to mining contract"
	@echo "  make verify           Verify contract on explorer"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean            Clean contract artifacts"

# ==============================================================================
# Smart Contracts
# ==============================================================================
compile:
	@echo "🔨 Compiling smart contracts..."
	~/.foundry/bin/forge build

bindings: abi-token abi-otcmarket abi-vault abi-revenue abi-referral abi-cashback abi-mining abi-stablecoin
	@echo "✅ Contract bindings generated!"

update: compile bindings
	@echo "🚀 Contracts updated!"

# Contract testing
test:
	@echo "🧪 Running contract tests..."
	~/.foundry/bin/forge test -vv

test-gas:
	@echo "⛽ Running contract tests with gas report..."
	~/.foundry/bin/forge test --gas-report

coverage:
	@echo "📊 Running contract coverage..."
	~/.foundry/bin/forge coverage

# Gas optimization
gas-snapshot:
	@echo "📸 Creating gas snapshot..."
	~/.foundry/bin/forge snapshot
	@echo "✅ Gas snapshot saved to .gas-snapshot"

gas-compare:
	@echo "📊 Comparing gas usage..."
	@test -f .gas-snapshot || (echo "❌ No baseline snapshot! Run: make gas-snapshot" && exit 1)
	~/.foundry/bin/forge snapshot --diff .gas-snapshot

# Deployment commands
deploy-local:
	@echo "🚀 Deploying to local Anvil..."
	@test -n "$(PRIVATE_KEY)" || (echo "❌ PRIVATE_KEY not set! Set it in .env" && exit 1)
	~/.foundry/bin/forge script script/DeployKawai.s.sol:DeployKawai \
		--rpc-url http://localhost:8545 \
		--private-key $(PRIVATE_KEY) \
		--broadcast

deploy-testnet:
	@echo "🚀 Deploying to Monad Testnet..."
	@test -n "$(PRIVATE_KEY)" || (echo "❌ PRIVATE_KEY not set!" && exit 1)
	@test -n "$(RPC_URL)" || (echo "❌ RPC_URL not set!" && exit 1)
	~/.foundry/bin/forge script script/DeployKawai.s.sol:DeployKawai \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify

deploy-vault:
	@echo "🚀 Deploying PaymentVault..."
	@test -n "$(PRIVATE_KEY)" || (echo "❌ PRIVATE_KEY not set!" && exit 1)
	@test -n "$(RPC_URL)" || (echo "❌ RPC_URL not set!" && exit 1)
	@test -n "$(STABLECOIN_ADDRESS)" || (echo "❌ STABLECOIN_ADDRESS not set! Set it in .env" && exit 1)
	@if [ "$(CHAIN_ID)" = "143" ] || echo "$(RPC_URL)" | grep -q "mainnet"; then \
		echo "⚠️  WARNING: Deploying to MAINNET with USDC $(STABLECOIN_ADDRESS)"; \
		echo "⚠️  This will cost real MON for gas fees"; \
		read -p "Continue with mainnet deployment? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1; \
	fi
	@echo "ℹ️  Stablecoin: $(STABLECOIN_ADDRESS)"
	~/.foundry/bin/forge script script/DeployPaymentVault.s.sol:DeployPaymentVault \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify
	@echo "✅ PaymentVault deployed!"
	@echo "⚠️  Update PAYMENT_VAULT_ADDRESS in .env"

deploy-referral-testnet:
	@echo "🚀 Deploying ReferralRewardDistributor to Monad Testnet..."
	@test -n "$(PRIVATE_KEY)" || (echo "❌ PRIVATE_KEY not set!" && exit 1)
	@test -n "$(RPC_URL)" || (echo "❌ RPC_URL not set!" && exit 1)
	@test -n "$(KAWAI_TOKEN_ADDRESS)" || (echo "❌ KAWAI_TOKEN_ADDRESS not set! Set it in .env" && exit 1)
	~/.foundry/bin/forge script script/DeployReferralDistributor.s.sol:DeployReferralDistributor \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify

grant-minter-referral:
	@echo "🔐 Granting MINTER_ROLE to ReferralRewardDistributor..."
	@test -n "$(PRIVATE_KEY)" || (echo "❌ PRIVATE_KEY not set!" && exit 1)
	@test -n "$(RPC_URL)" || (echo "❌ RPC_URL not set!" && exit 1)
	@test -n "$(KAWAI_TOKEN_ADDRESS)" || (echo "❌ KAWAI_TOKEN_ADDRESS not set!" && exit 1)
	@test -n "$(REFERRAL_DISTRIBUTOR_ADDRESS)" || (echo "❌ REFERRAL_DISTRIBUTOR_ADDRESS not set!" && exit 1)
	@echo "Granting MINTER_ROLE to $(REFERRAL_DISTRIBUTOR_ADDRESS)..."
	cast send $(KAWAI_TOKEN_ADDRESS) \
		"grantRole(bytes32,address)" \
		$$(cast keccak "MINTER_ROLE") \
		$(REFERRAL_DISTRIBUTOR_ADDRESS) \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY)
	@echo "✅ MINTER_ROLE granted!"

deploy-cashback-testnet:
	@echo "🚀 Deploying DepositCashbackDistributor to Monad Testnet..."
	@test -n "$(PRIVATE_KEY)" || (echo "❌ PRIVATE_KEY not set!" && exit 1)
	@test -n "$(RPC_URL)" || (echo "❌ RPC_URL not set!" && exit 1)
	@test -n "$(KAWAI_TOKEN_ADDRESS)" || (echo "❌ KAWAI_TOKEN_ADDRESS not set! Set it in .env" && exit 1)
	~/.foundry/bin/forge script script/DeployCashbackDistributor.s.sol:DeployCashbackDistributor \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify

grant-minter-cashback:
	@echo "🔐 Granting MINTER_ROLE to DepositCashbackDistributor..."
	@test -n "$(PRIVATE_KEY)" || (echo "❌ PRIVATE_KEY not set!" && exit 1)
	@test -n "$(RPC_URL)" || (echo "❌ RPC_URL not set!" && exit 1)
	@test -n "$(KAWAI_TOKEN_ADDRESS)" || (echo "❌ KAWAI_TOKEN_ADDRESS not set!" && exit 1)
	@test -n "$(CASHBACK_DISTRIBUTOR_ADDRESS)" || (echo "❌ CASHBACK_DISTRIBUTOR_ADDRESS not set!" && exit 1)
	@echo "Granting MINTER_ROLE to $(CASHBACK_DISTRIBUTOR_ADDRESS)..."
	cast send $(KAWAI_TOKEN_ADDRESS) \
		"grantRole(bytes32,address)" \
		$$(cast keccak "MINTER_ROLE") \
		$(CASHBACK_DISTRIBUTOR_ADDRESS) \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY)
	@echo "✅ MINTER_ROLE granted!"

deploy-mining-testnet:
	@echo "🚀 Deploying MiningRewardDistributor to Monad Testnet..."
	@test -n "$(PRIVATE_KEY)" || (echo "❌ PRIVATE_KEY not set!" && exit 1)
	@test -n "$(RPC_URL)" || (echo "❌ RPC_URL not set!" && exit 1)
	@test -n "$(KAWAI_TOKEN_ADDRESS)" || (echo "❌ KAWAI_TOKEN_ADDRESS not set! Set it in .env" && exit 1)
	@echo "ℹ️  Note: Developer addresses are specified per claim (flexible distribution)"
	~/.foundry/bin/forge script script/DeployMiningDistributor.s.sol:DeployMiningDistributor \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify

grant-minter-mining:
	@echo "🔐 Granting MINTER_ROLE to MiningRewardDistributor..."
	@test -n "$(PRIVATE_KEY)" || (echo "❌ PRIVATE_KEY not set!" && exit 1)
	@test -n "$(RPC_URL)" || (echo "❌ RPC_URL not set!" && exit 1)
	@test -n "$(KAWAI_TOKEN_ADDRESS)" || (echo "❌ KAWAI_TOKEN_ADDRESS not set!" && exit 1)
	@test -n "$(MINING_DISTRIBUTOR_ADDRESS)" || (echo "❌ MINING_DISTRIBUTOR_ADDRESS not set!" && exit 1)
	@echo "Granting MINTER_ROLE to $(MINING_DISTRIBUTOR_ADDRESS)..."
	cast send $(KAWAI_TOKEN_ADDRESS) \
		"grantRole(bytes32,address)" \
		$$(cast keccak "MINTER_ROLE") \
		$(MINING_DISTRIBUTOR_ADDRESS) \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY)
	@echo "✅ MINTER_ROLE granted!"

verify:
	@echo "✅ Verifying contracts on explorer..."
	@test -n "$(CONTRACT_ADDRESS)" || (echo "❌ CONTRACT_ADDRESS not set!" && exit 1)
	@test -n "$(ETHERSCAN_API_KEY)" || (echo "❌ ETHERSCAN_API_KEY not set!" && exit 1)
		~/.foundry/bin/forge verify-contract \
			$(CONTRACT_ADDRESS) \
			contracts/OTCMarket.sol:OTCMarket \
			--chain-id $(CHAIN_ID) \
			--etherscan-api-key $(ETHERSCAN_API_KEY)

clean:
	@echo "🧹 Cleaning contract artifacts..."
	~/.foundry/bin/forge clean
	@echo "✅ Contract artifacts cleaned!"

# ==============================================================================
# ABI Generation
# ==============================================================================
generate-project-abis:
	@echo "📦 Injecting project ABIs into Jarvis..."
	@go run ./cmd/generate-abis project_abis.go $(ABIS_DIR)

abi-token:
	@mkdir -p $(ABIS_DIR)/kawaitoken
	@jq -r .abi $(TOKEN_ARTIFACT) > $(ABIS_DIR)/kawaitoken/KawaiToken.abi
	@jq -r .bytecode.object $(TOKEN_ARTIFACT) > $(ABIS_DIR)/kawaitoken/KawaiToken.bin
	@abigen --abi $(ABIS_DIR)/kawaitoken/KawaiToken.abi --bin $(ABIS_DIR)/kawaitoken/KawaiToken.bin \
		--pkg kawaitoken --type KawaiToken --out $(ABIS_DIR)/kawaitoken/kawaitoken.go

abi-otcmarket:
	@mkdir -p $(ABIS_DIR)/otcmarket
	@jq -r .abi $(OTCMARKET_ARTIFACT) > $(ABIS_DIR)/otcmarket/OTCMarket.abi
	@jq -r .bytecode.object $(OTCMARKET_ARTIFACT) > $(ABIS_DIR)/otcmarket/OTCMarket.bin
	@abigen --abi $(ABIS_DIR)/otcmarket/OTCMarket.abi --bin $(ABIS_DIR)/otcmarket/OTCMarket.bin \
		--pkg otcmarket --type OTCMarket --out $(ABIS_DIR)/otcmarket/otcmarket.go

abi-vault:
	@mkdir -p $(ABIS_DIR)/vault
	@jq -r .abi $(VAULT_ARTIFACT) > $(ABIS_DIR)/vault/PaymentVault.abi
	@jq -r .bytecode.object $(VAULT_ARTIFACT) > $(ABIS_DIR)/vault/PaymentVault.bin
	@abigen --abi $(ABIS_DIR)/vault/PaymentVault.abi --bin $(ABIS_DIR)/vault/PaymentVault.bin \
		--pkg vault --type PaymentVault --out $(ABIS_DIR)/vault/vault.go

abi-revenue:
	@mkdir -p $(ABIS_DIR)/revenuedistributor
	@jq -r .abi $(REVENUE_ARTIFACT) > $(ABIS_DIR)/revenuedistributor/RevenueDistributor.abi
	@jq -r .bytecode.object $(REVENUE_ARTIFACT) > $(ABIS_DIR)/revenuedistributor/RevenueDistributor.bin
	@abigen --abi $(ABIS_DIR)/revenuedistributor/RevenueDistributor.abi --bin $(ABIS_DIR)/revenuedistributor/RevenueDistributor.bin \
		--pkg revenuedistributor --type RevenueDistributor --out $(ABIS_DIR)/revenuedistributor/revenuedistributor.go

abi-referral:
	@mkdir -p $(ABIS_DIR)/referraldistributor
	@jq -r .abi $(REFERRAL_ARTIFACT) > $(ABIS_DIR)/referraldistributor/ReferralRewardDistributor.abi
	@jq -r .bytecode.object $(REFERRAL_ARTIFACT) > $(ABIS_DIR)/referraldistributor/ReferralRewardDistributor.bin
	@abigen --abi $(ABIS_DIR)/referraldistributor/ReferralRewardDistributor.abi --bin $(ABIS_DIR)/referraldistributor/ReferralRewardDistributor.bin \
		--pkg referraldistributor --type ReferralRewardDistributor --out $(ABIS_DIR)/referraldistributor/referraldistributor.go

abi-cashback:
	@mkdir -p $(ABIS_DIR)/cashbackdistributor
	@jq -r .abi $(CASHBACK_ARTIFACT) > $(ABIS_DIR)/cashbackdistributor/DepositCashbackDistributor.abi
	@jq -r .bytecode.object $(CASHBACK_ARTIFACT) > $(ABIS_DIR)/cashbackdistributor/DepositCashbackDistributor.bin
	@abigen --abi $(ABIS_DIR)/cashbackdistributor/DepositCashbackDistributor.abi --bin $(ABIS_DIR)/cashbackdistributor/DepositCashbackDistributor.bin \
		--pkg cashbackdistributor --type DepositCashbackDistributor --out $(ABIS_DIR)/cashbackdistributor/cashbackdistributor.go

abi-mining:
	@mkdir -p $(ABIS_DIR)/miningdistributor
	@jq -r .abi $(MINING_ARTIFACT) > $(ABIS_DIR)/miningdistributor/MiningRewardDistributor.abi
	@jq -r .bytecode.object $(MINING_ARTIFACT) > $(ABIS_DIR)/miningdistributor/MiningRewardDistributor.bin
	@abigen --abi $(ABIS_DIR)/miningdistributor/MiningRewardDistributor.abi --bin $(ABIS_DIR)/miningdistributor/MiningRewardDistributor.bin \
		--pkg miningdistributor --type MiningRewardDistributor --out $(ABIS_DIR)/miningdistributor/miningdistributor.go

abi-stablecoin:
	@mkdir -p $(ABIS_DIR)/mockstablecoin
	@jq -r .abi $(STABLECOIN_ARTIFACT) > $(ABIS_DIR)/mockstablecoin/MockStablecoin.abi
	@jq -r .bytecode.object $(STABLECOIN_ARTIFACT) > $(ABIS_DIR)/mockstablecoin/MockStablecoin.bin
	@abigen --abi $(ABIS_DIR)/mockstablecoin/MockStablecoin.abi --bin $(ABIS_DIR)/mockstablecoin/MockStablecoin.bin \
		--pkg mockstablecoin --type MockStablecoin --out $(ABIS_DIR)/mockstablecoin/mockstablecoin.go
