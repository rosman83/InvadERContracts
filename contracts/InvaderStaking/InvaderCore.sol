// SPDX-License-Identifier: NONE

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract InvaderStaking is ERC20Burnable, Ownable {
    uint256 public constant MAX_WALLET_STAKED = 30;
    uint256 public constant EMISSIONS_RATE = 115740740740740; // 10e18 (Rate by Decimals)/ 86400 (Daily Secs)
    address public constant ADDRESS = 0x246e29ef6987637e48e7509F91521Ce64EB8c831;
    bool public stakingLive;

    mapping(uint256 => uint256) internal TokenIdTimeStaked;
    mapping(uint256 => address) internal TokenIdToStaker;
    mapping(address => uint256[]) internal StakerToTokenIds;
    
    IERC721Enumerable private constant _IERC721Enumerable = IERC721Enumerable(ADDRESS);

    constructor() ERC20("Catnip", "CATNIP") {}

    modifier stakingEnabled {
        require(stakingLive, "STAKING_NOT_LIVE");
        _;
    }

    function getTokensStaked(address staker) public view returns (uint256[] memory) {
        return StakerToTokenIds[staker];
    }
    
    function getStakedCount(address staker) public view returns (uint256) {
        return StakerToTokenIds[staker].length;
    }

    function removeTokenIdFromArray(uint256[] storage array, uint256 tokenId) internal {
        uint256 length = array.length;
        for (uint256 i = 0; i < length; i++) {
            if (array[i] == tokenId) {
                length--;
                if (i < length) {
                    array[i] = array[length];
                }
                array.pop();
                break;
            }
        }
    }

    function stakeTokensByIds(uint256[] memory tokenIds) public stakingEnabled {
        require(getStakedCount(msg.sender) + tokenIds.length <= MAX_WALLET_STAKED, "MAX_TOKENS_STAKED_PER_WALLET");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 id = tokenIds[i];
            require(_IERC721Enumerable.ownerOf(id) == msg.sender && TokenIdToStaker[id] == address(0), "TOKEN_IS_NOT_YOURS");
            _IERC721Enumerable.transferFrom(msg.sender, address(this), id);

            StakerToTokenIds[msg.sender].push(id);
            TokenIdTimeStaked[id] = block.timestamp;
            TokenIdToStaker[id] = msg.sender;
        }
    }

    function unstakeAll() public {
        require(getStakedCount(msg.sender) > 0, "NEED_ONE_STAKED");
        uint256 totalRewards = 0;

        for (uint256 i = StakerToTokenIds[msg.sender].length; i > 0; i--) {
            uint256 tokenId = StakerToTokenIds[msg.sender][i - 1];

            _IERC721Enumerable.transferFrom(address(this), msg.sender, tokenId);
            totalRewards += ((block.timestamp - TokenIdTimeStaked[tokenId]) * EMISSIONS_RATE);
            StakerToTokenIds[msg.sender].pop();
            TokenIdToStaker[tokenId] = address(0);
        }

        _mint(msg.sender, totalRewards);
    }

    function unstakeTokensByIds(uint256[] memory tokenIds) public {
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 id = tokenIds[i];
            require(TokenIdToStaker[id] == msg.sender, "NOT_ORIGINAL_STAKER");

            _IERC721Enumerable.transferFrom(address(this), msg.sender, id);
            totalRewards += ((block.timestamp - TokenIdTimeStaked[id]) * EMISSIONS_RATE);

            removeTokenIdFromArray(StakerToTokenIds[msg.sender], id);
            TokenIdToStaker[id] = address(0);
        }

        _mint(msg.sender, totalRewards);
    }

    function claimByTokenId(uint256 tokenId) public {
        require(TokenIdToStaker[tokenId] == msg.sender, "NOT_STAKED_BY_YOU");
        _mint(msg.sender, ((block.timestamp - TokenIdTimeStaked[tokenId]) * EMISSIONS_RATE));
        TokenIdTimeStaked[tokenId] = block.timestamp;
    }

    function claimAll() public {
        uint256 totalRewards = 0;

        uint256[] memory tokenIds = StakerToTokenIds[msg.sender];
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 id = tokenIds[i];
            require(TokenIdToStaker[id] == msg.sender, "NOT_STAKED_BY_YOU");
            totalRewards += ((block.timestamp - TokenIdTimeStaked[id]) * EMISSIONS_RATE);
            TokenIdTimeStaked[id] = block.timestamp;
        }

        _mint(msg.sender, totalRewards);
    }

    function getAllRewards(address staker) public view returns (uint256) {
        uint256 totalRewards = 0;

        uint256[] memory TokenIds = StakerToTokenIds[staker];
        for (uint256 i = 0; i < TokenIds.length; i++) {
            totalRewards += ((block.timestamp - TokenIdTimeStaked[TokenIds[i]]) * EMISSIONS_RATE);
        }

        return totalRewards;
    }

    function getRewardsByTokenId(uint256 tokenId) public view returns (uint256) {
        require(TokenIdToStaker[tokenId] != address(0), "TOKEN_NOT_STAKED");

        uint256 secondsStaked = block.timestamp - TokenIdTimeStaked[tokenId];
        return secondsStaked * EMISSIONS_RATE;
    }

    function getTokenStaker(uint256 tokenId) public view returns (address) {
        return TokenIdToStaker[tokenId];
    }

    function toggle() external onlyOwner {
        stakingLive = !stakingLive;
    }
}