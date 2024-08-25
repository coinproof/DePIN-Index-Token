
// SPDX-License-Identifier: MIT

/*
    Overview:
    This contract provides an ERC-20 compliant token that represents an index of three DePIN tokens, 
    each with a different weightage in the index. The index token’s supply is dynamically adjusted 
    (“rebalanced”) based on the price changes of the underlying DePIN tokens, ensuring that the value 
    of the index token reflects the aggregate value of the staked DePIN tokens.

    Features:
    1.	Staking Mechanism:
	    •	Users can stake any of the three DePIN tokens to mint index tokens. The amount of index 
            tokens minted corresponds to the weightage of the DePIN token staked.
	    •	The staking duration is set to 1 year by default but can be modified by the contract owner.
	2.	Unstaking Mechanism:
	    •	Users can unstake their DePIN tokens after the lock-up period, which results in burning the 
            corresponding amount of index tokens.
	3.	Price Updates and Rebalancing:
	    •	The owner can update the prices of the DePIN tokens through a centralized oracle.
	    •	When prices are updated, the total supply of index tokens is rebased, either increasing 
            or decreasing based on the price changes and weightage of the DePIN tokens.
	    •	The balances of all holders are adjusted proportionally during rebalancing to reflect the 
            new total supply.
	4.	Error Handling:
	    •	The contract uses the latest Solidity error reporting mechanisms (error statements) for 
            efficient gas usage and clear error messages.
	    •	Custom errors include InsufficientBalance, TokensLocked, InvalidTokenID and ZeroAddress.
	5.	Security:
	    •	The contract implements the nonReentrant modifier from the ReentrancyGuard contract to 
            protect against reentrancy attacks.
	    •	The contract follows the “Checks-Effects-Interactions” pattern to ensure security during 
            external calls.

    Limitations & Scope of updates: (These updates are out of the scope of this assignement)

    1.  The contract assumes that the staker will only stake once and is designed in that way. It does allow
        staking more of the same DePIN token, but resets the staking period to 365 days from last stake.
        It is desirable to maintain separate staking IDs for each stake which allows user to unstake each 
        staked amount after staking duration ends.
    2.  Use of centralized price update mechanism for DePIN tokens. It is desireable to integrate 
        decentralized oracle service for automated price updates for underlying DePIN tokens.
    3.  Hard coded weightage for each DePIN token. Can be set to vary as per the fluctuation in price.
        DePIN token with highest price value should have more proportional weightage.
    4.  The scaling factor and rebasing are not optimized and synchronized to yield desirable results. Also upon transfer
        the balances might not tally. The rebasing logic can further be refined.
*/
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DePINIndexToken is ERC20, Ownable, ReentrancyGuard {
    IERC20 public depinToken1;
    IERC20 public depinToken2;
    IERC20 public depinToken3;

    uint256 public stakingDuration = 1 days; // Default staking duration of 1 day, can be updated by contrat owner
    uint256 public constant WEIGHT_TOKEN1 = 40;
    uint256 public constant WEIGHT_TOKEN2 = 30;
    uint256 public constant WEIGHT_TOKEN3 = 30;

    uint256 public scalingFactor = 1e18; // Starts at 1 (1e18 for precision)
    uint256 public constant BASE = 1e18; // Base for precision

    mapping(address => mapping(uint256 => uint256)) public stakes; // user -> token ID -> amount
    mapping(address => mapping(uint256 => uint256)) public lockedUntil; // user -> token ID -> stakeDuration
    mapping(uint256 => uint256) public tokenPrices; // token ID -> price. The price is assumed as total DePIN tokens (in wei) per USDT

    error InsufficientBalance(uint256 requested, uint256 available);
    error TokensLocked(uint256 until);
    error InvalidTokenID(uint256 tokenID);
    error NoChangeInPrice(uint256 oldPrice, uint256 newPrice);

    event PriceUpdated(uint256 tokenID, uint256 oldPrice, uint256 newPrice);
    event Staked(address indexed user, uint256 tokenID, uint256 amount);
    event Unstaked(address indexed user, uint256 tokenID, uint256 amount);
    event Rebased(uint256 oldScalingFactor, uint256 newScalingFactor);

    constructor()
        // address _depinToken1,
        // address _depinToken2,
        // address _depinToken3
        ERC20("DePIN Index Token", "DPINDEX")
    {
        depinToken1 = IERC20(0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8);
        depinToken2 = IERC20(0xf8e81D47203A594245E36C48e151709F0C19fBe8);
        depinToken3 = IERC20(0xD7ACd2a9FD159E69Bb102A1ca21C9a3e3A5F771B);

        tokenPrices[1] = 2500 * BASE;
        tokenPrices[2] = 1500 * BASE;
        tokenPrices[3] = 500 * BASE;
    }

    function updateStakingDuration(uint256 _duration) external onlyOwner {
        require(_duration >= 1, "Error: Can't set to less than 1 day");
        stakingDuration = _duration * 1 days; // converted to days
    }

    function stake(uint256 tokenID, uint256 amount) external {
        if (tokenID != 1 && tokenID != 2 && tokenID != 3)
            revert InvalidTokenID(tokenID);

        IERC20 depinToken = getDepinToken(tokenID);
        try depinToken.transferFrom(msg.sender, address(this), amount) returns (
            bool success
        ) {
            require(success, "Transfer failed");
        } catch Error(string memory reason) {
            revert(reason);
        } catch (bytes memory) {
            revert("Transfer failed with low-level error");
        }

        uint256 indexTokenAmount = calculateIndexTokenAmount(tokenID, amount);

        uint256 mintAmount = (indexTokenAmount * BASE) / scalingFactor;

        _mint(msg.sender, mintAmount);
        lockedUntil[msg.sender][tokenID] = block.timestamp + stakingDuration;

        stakes[msg.sender][tokenID] += amount;

        emit Staked(msg.sender, tokenID, amount);
    }

    function unstake(uint256 tokenID) external nonReentrant {
        if (block.timestamp < lockedUntil[msg.sender][tokenID])
            revert TokensLocked(lockedUntil[msg.sender][tokenID]);

        uint256 amount = stakes[msg.sender][tokenID];
        if (amount == 0) revert InsufficientBalance(0, amount);

        uint256 indexTokenAmount = calculateIndexTokenAmount(tokenID, amount);
        uint256 indexTokensToBurn = (indexTokenAmount * BASE) / scalingFactor;
        // Ensure staker has sufficient index tokens in case of negative rebase
        uint256 userBalance = balanceOf(msg.sender);
        if (indexTokensToBurn > userBalance) {
            _burn(msg.sender, userBalance);
        } else {
            _burn(msg.sender, indexTokensToBurn);
        }

        stakes[msg.sender][tokenID] = 0;

        IERC20 depinToken = getDepinToken(tokenID);
        require(depinToken.transfer(msg.sender, amount), "Transfer failed");

        emit Unstaked(msg.sender, tokenID, amount);
    }

    function updateTokenPrice(uint256 tokenID, uint256 newPrice)
        external
        onlyOwner
    {
        uint256 oldPrice = tokenPrices[tokenID];
        if (newPrice != oldPrice) {
            tokenPrices[tokenID] = newPrice * BASE; // conversion to wei
            rebaseSupply(tokenID, oldPrice, newPrice * BASE);
            emit PriceUpdated(tokenID, oldPrice, newPrice * BASE);
        } else {
            revert NoChangeInPrice(oldPrice, newPrice * BASE);
        }
    }

    function rebaseSupply(
        uint256 tokenID,
        uint256 oldPrice,
        uint256 newPrice
    ) internal {
        uint256 priceDelta = newPrice / oldPrice;
        uint256 weight = getTokenWeight(tokenID);
        uint256 rebaseRatio = (priceDelta * weight) / 100;

        uint256 newScalingFactor = (scalingFactor * rebaseRatio) / BASE;
        require(newScalingFactor > 0, "Scaling factor cannot be zero");

        scalingFactor = newScalingFactor;

        emit Rebased(scalingFactor, newScalingFactor);
    }

    function getDepinToken(uint256 tokenID) internal view returns (IERC20) {
        if (tokenID == 1) return depinToken1;
        if (tokenID == 2) return depinToken2;
        return depinToken3;
    }

    function calculateIndexTokenAmount(uint256 tokenID, uint256 depinAmount)
        internal
        pure
        returns (uint256)
    {
        if (tokenID == 1) return (depinAmount * WEIGHT_TOKEN1) / 100;
        if (tokenID == 2) return (depinAmount * WEIGHT_TOKEN2) / 100;
        return (depinAmount * WEIGHT_TOKEN3) / 100;
    }

    function getTokenWeight(uint256 tokenID) internal pure returns (uint256) {
        if (tokenID == 1) return WEIGHT_TOKEN1;
        if (tokenID == 2) return WEIGHT_TOKEN2;
        return WEIGHT_TOKEN3;
    }

    function totalSupply() public view virtual override returns (uint256) {
        // Return the rebased total supply
        return (super.totalSupply() * scalingFactor) / BASE;
    }

    // Override the _update function to apply scaling factor
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        // Adjust the transfer amount based on the scaling factor
        uint256 adjustedAmount = (amount * scalingFactor) / BASE;

        if (from == address(0)) {
            // Minting case
            _totalSupply += adjustedAmount;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < adjustedAmount) {
                revert("ERC20: insufficient balance");
            }
            unchecked {
                _balances[from] = fromBalance - adjustedAmount;
            }
        }

        if (to == address(0)) {
            // Burning case
            unchecked {
                _totalSupply -= adjustedAmount;
            }
        } else {
            unchecked {
                _balances[to] += adjustedAmount;
            }
        }

        emit Transfer(from, to, adjustedAmount);
    }
}
