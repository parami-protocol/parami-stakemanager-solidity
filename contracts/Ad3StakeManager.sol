// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import "./interfaces/IAd3StakeManager.sol";
import "./libraries/NFTPositionInfo.sol";
import "./libraries/IncentiveId.sol";
import "./libraries/RewardMath.sol";

contract Ad3StakeManager is IAd3StakeManager, ReentrancyGuardUpgradeable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    IUniswapV3Factory public override factory;
    INonfungiblePositionManager public override nonfungiblePositionManager;

    /// @dev deposits[tokenId] => Deposit
    mapping(uint256 => Deposit) public override deposits;

    /// @dev stakes[incentiveId][tokenId] => Stake
    mapping(bytes32 => mapping(uint256 => Stake)) private _stakes;

    /// @dev rewards[rewardToken][owner] => uint256
    mapping(address => mapping(address => uint256)) public override rewards;

    /// @dev bytes32 refers to the return value of IncentiveId.compute
    mapping(bytes32 => Incentive) public override incentives;

    mapping(address => EnumerableSet.UintSet) private _userTokenIds;
    EnumerableSet.UintSet private _tokenIds;

    address public deployer;
    address public gov;
    address public nextgov;

    modifier onlyGov() {
        require(msg.sender == gov || msg.sender == deployer, "only gov");
        _;
    }

    modifier isAuthorizedForToken(uint256 tokenId) {
        require(
            msg.sender == nonfungiblePositionManager.ownerOf(tokenId),
            "not approved"
        );
        _;
    }

    // initialize
    function initialize(
        address _gov,
        address _factory,
        address _nonfungiblePositionManager
    ) public initializer {
        gov = _gov;
        factory = IUniswapV3Factory(_factory);
        nonfungiblePositionManager = INonfungiblePositionManager(
            _nonfungiblePositionManager
        );
    }

    function setGoverance(address _gov) external onlyGov {
        nextgov = _gov;
    }

    function acceptGoverance() external {
        require(msg.sender == nextgov, "not gov");
        gov = msg.sender;
        nextgov = address(0);
    }

    /** 
    update the stake range of a incentive which is already created, require caller is governor
    @dev update minTick & maxTick of incentives[IncentiveId.compute(key)]
    @param key The IncentiveKey struct which defined in IAd3StakeManager
    @param tickLower The minimum tick allowed for staking in this new incentive
    @param tickUpper The maximum tick allowed for staking in this new incentive
    [return] no return, no event
    */
    function updateRange(
        IncentiveKey memory key,
        int24 tickLower,
        int24 tickUpper
    ) external override onlyGov {
        Incentive storage incentive = incentives[IncentiveId.compute(key)];
        incentive.minTick = tickLower;
        incentive.maxTick = tickUpper;
    }

    function getUserTokenIdCount(address to)
        external
        view
        override
        returns (uint256)
    {
        return _userTokenIds[to].length();
    }

    function getTokenId(address to, uint256 index)
        external
        view
        override
        returns (uint256 tokenId)
    {
        require(
            index < _userTokenIds[to].length(),
            "overflow tokenId set length"
        );
        return _userTokenIds[to].at(index);
    }

    function getTokenIdCount() external view override returns (uint256 index) {
        return _tokenIds.length();
    }

    function getTokenId(uint256 index)
        external
        view
        override
        returns (uint256 tokenId)
    {
        require(index < _tokenIds.length(), "overflow tokenId set length");
        return _tokenIds.at(index);
    }

    /** 
    query a stake by incentiveId and tokenId
    @notice query {owner, liquidity, secondsPerLiquidityInsideInitialX128, secondsPerLiquidityInsideAccruedX128 } of a stake by incentiveId and tokenId 
    @dev incentiveId = IncentiveId.compute(IncentiveKey)
    @param incentiveId The hash of the IncentiveKey
    @param tokenId The LP tokenId
    [return] {owner, liquidity, secondsPerLiquidityInsideInitialX128, secondsPerLiquidityInsideAccruedX128 }
    */
    function stakes(bytes32 incentiveId, uint256 tokenId)
        public
        view
        override
        returns (
            address owner,
            uint128 liquidity,
            uint160 secondsPerLiquidityInsideInitialX128,
            uint160 secondsPerLiquidityInsideAccruedX128
        )
    {
        Stake memory stake = _stakes[incentiveId][tokenId];
        owner = stake.owner;
        secondsPerLiquidityInsideInitialX128 = stake
            .secondsPerLiquidityInsideInitialX128;
        liquidity = stake.liquidity;
        secondsPerLiquidityInsideAccruedX128 = stake
            .secondsPerLiquidityInsideAccruedX128;
    }

    /** 
    createIncentive creates a liquidity mining incentive program. The key used to look up an Incentive is the hash of its immutable properties.
    @notice create a new incentive by governor, 
        [require] block.timestamp < key.startTime < key.endTime < (key.startTime + 2 months)
        [require] Incentive with this ID(hash(Key)) does not already exist.
        [effect] transfer msg.sender to self
        [effect] Sets incentives[key] = Incentive(totalRewardUnclaimed=totalReward, totalSecondsClaimedX128=0, rewardToken=rewardToken)
        [interaction] emit IncentiveCreated
    @param key The IncentiveKey struct which defined in IAd3StakeManager
    @param reward The total reward amount of this new incentive
    @param minTick The minimum tick allowed for staking in this new incentive
    @param maxTick The maximum tick allowed for staking in this new incentive
    [return] no return but emit IncentiveCreated
    */
    function createIncentive(
        IncentiveKey memory key,
        uint256 reward,
        int24 minTick,
        int24 maxTick
    ) external override onlyGov {
        require(reward > 0, "reward must be positive");
        require(
            block.timestamp <= key.startTime,
            "start time must be now or in the future"
        );
        require(
            key.startTime < key.endTime,
            "start time must be before end time"
        );
        require(
            key.endTime - key.startTime <= 2 * 30 * 24 * 60 * 60,
            "incentive duration is too long"
        ); //TODO: remove hardcoded value
        bytes32 incentiveId = IncentiveId.compute(key);
        require(
            incentives[incentiveId].totalRewardUnclaimed == 0,
            "incentive already exists"
        );

        incentives[incentiveId] = Incentive({
            totalRewardUnclaimed: reward,
            totalSecondsClaimedX128: 0,
            numberOfStakes: 0,
            minTick: minTick,
            maxTick: maxTick
        });

        // Owner transfer token to this contract
        TransferHelper.safeTransferFrom(
            key.rewardToken,
            msg.sender,
            address(this),
            reward
        );

        emit IncentiveCreated(
            key.rewardToken,
            key.pool,
            key.startTime,
            key.endTime,
            reward
        );
    }

    /** 
    cancelIncentive cancel a liquidity mining incentive program. The key used to look up an Incentive is the hash of its immutable properties.
    @notice cancel a incentive that already exists by governor, the unclaimed reward of this incentive will be returned to the refundee(an address)
        [require] rewardUnclaimed > 0
        [require]  block.timestamp > incentive.endTime, which means the incentive is already expired
        [effect] incentives[incentiveId].totalRewardUnclaimed = 0;
        [effect] Transfer(key.rewardToken, refundee, rewardUnclaimed);
        [interaction] emit IncentiveCancelled
    @param key The IncentiveKey struct which defined in IAd3StakeManager
    @param refundee The refundee address
    [return] no return but emit IncentiveCanceled(incentiveId, rewardUnclaimed);
    */
    function cancelIncentive(IncentiveKey memory key, address refundee)
        external
        override
        onlyGov
    {
        bytes32 incentiveId = IncentiveId.compute(key);
        Incentive memory incentive = incentives[incentiveId];
        uint256 rewardUnclaimed = incentive.totalRewardUnclaimed;
        require(rewardUnclaimed > 0, "no refund available");
        require(
            block.timestamp > key.endTime,
            "cannot cancel incentive before end time"
        );

        // if any unclaimed rewards remain, and we're past the claim deadline, issue a refund
        incentives[incentiveId].totalRewardUnclaimed = 0;
        TransferHelper.safeTransfer(key.rewardToken, refundee, rewardUnclaimed);
        emit IncentiveCanceled(incentiveId, rewardUnclaimed);
    }

    /// @inheritdoc IERC721Receiver
    /// @notice the real stake logic entry
    function onERC721Received(
        address,
        address operator,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        require(
            msg.sender == address(nonfungiblePositionManager),
            "not a univ3 nft"
        );

        (
            ,
            ,
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            ,
            ,
            ,
            ,

        ) = nonfungiblePositionManager.positions(tokenId);
        deposits[tokenId] = Deposit({
            owner: operator,
            numberOfStakes: 0,
            tickLower: tickLower,
            tickUpper: tickUpper
        });

        emit TokenReceived(tokenId, operator);

        if (data.length > 0) {
            IncentiveKey memory key = abi.decode(data, (IncentiveKey));
            _stakeToken(key, tokenId, operator);
        }
        return this.onERC721Received.selector;
    }

    /** 
    depositToken make a deposit reqeust.
    @param key The IncentiveKey struct which defined in IAd3StakeManager
    @param tokenId The LP nft token id
    [return] no return
    */
    function depositToken(IncentiveKey memory key, uint256 tokenId)
        external
        override
        isAuthorizedForToken(tokenId)
    {
        require(block.timestamp >= key.startTime, "incentive not started");
        require(block.timestamp <= key.endTime, "incentive has ended");

        nonfungiblePositionManager.safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            abi.encode(key)
        );
    }

    /** 
    _stakeToken is the real stake logic entry, intelnal use only.
    @notice stake a LP token which is from the UniswapV3 pool when the LP nft is received
        [require] block.timestamp >= key.startTime, which means the incentive is not started
        [require] block.timestamp <= key.endTime, which means the incentive is not expired
        [require] incentives[incentiveId].totalRewardUnclaimed != 0, which means the incentive is ready
        [effect]  update StateVar _stakes with this new stake
        [interaction] emit TokenStaked(incentiveId, tokenId, liquidity)
    @param key The IncentiveKey struct which defined in IAd3StakeManager, intelnal use only
    @param tokenId The LP token id, intelnal use only
    @param operator The operator address, intelnal use only
    [return] no return but emit TokenStaked(incentiveId, tokenId, liquidity)
    */
    function _stakeToken(
        IncentiveKey memory key,
        uint256 tokenId,
        address operator
    ) internal {
        require(block.timestamp >= key.startTime, "incentive not started");
        require(block.timestamp <= key.endTime, "incentive has ended");

        bytes32 incentiveId = IncentiveId.compute(key);
        Incentive storage incentive = incentives[incentiveId];
        Deposit storage deposit = deposits[tokenId];

        require(incentive.totalRewardUnclaimed > 0, "non-existent incentive");

        (
            IUniswapV3Pool pool,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity
        ) = NFTPositionInfo.getPositionInfo(
                factory,
                nonfungiblePositionManager,
                tokenId
            );
        require(pool == key.pool, "token pool is not incentive pool");
        require(liquidity > 0, "can not stake token with 0 liquidity");

        deposit.numberOfStakes = deposit.numberOfStakes + 1;
        incentive.numberOfStakes = incentive.numberOfStakes + 1;

        (, uint160 secondsPerLiquidityInsideX128, ) = pool
            .snapshotCumulativesInside(tickLower, tickUpper);

        _stakes[incentiveId][tokenId] = Stake({
            secondsPerLiquidityInsideInitialX128: secondsPerLiquidityInsideX128,
            secondsPerLiquidityInsideAccruedX128: secondsPerLiquidityInsideX128,
            liquidity: liquidity,
            owner: operator
        });
        _userTokenIds[operator].add(tokenId);
        _tokenIds.add(tokenId);
        emit TokenStaked(incentiveId, tokenId, liquidity);
    }

    /** 
    _cleanReward when unstake a LP token.
    [interaction] transfer the reward to the operator
    */

    function _cleanReward(
        Deposit storage deposit,
        Incentive storage incentive,
        uint256 reward,
        uint160 secondsInsideX128,
        address rewardToken,
        address to
    ) internal {
        deposit.numberOfStakes = deposit.numberOfStakes > 1
            ? deposit.numberOfStakes - 1
            : 0;
        incentive.numberOfStakes = deposit.numberOfStakes > 1
            ? deposit.numberOfStakes - 1
            : 0;

        // update reward info if range in [minTick, maxTick]
        if (deposit.tickLower >= incentive.minTick) {
            incentive.totalSecondsClaimedX128 = uint160(
                SafeMath.add(
                    incentive.totalSecondsClaimedX128,
                    secondsInsideX128
                )
            );
            incentive.totalRewardUnclaimed = incentive.totalRewardUnclaimed.sub(
                reward
            );
            rewards[rewardToken][msg.sender] = rewards[rewardToken][msg.sender]
                .add(reward);
        }
        if (rewards[rewardToken][msg.sender] > 0) {
            uint256 totalReward = rewards[rewardToken][msg.sender];
            rewards[rewardToken][msg.sender] = 0;
            TransferHelper.safeTransfer(rewardToken, to, totalReward);
        }
    }

    /**
    [effect] delete the stake info from constract
    [intraction] transfer the LP token to the operator
    */
    function _cleanStake(
        bytes32 incentiveId,
        uint256 tokenId,
        address to
    ) internal {
        // cleaning _stakes
        _stakes[incentiveId][tokenId].secondsPerLiquidityInsideInitialX128 = 0;
        _stakes[incentiveId][tokenId].secondsPerLiquidityInsideAccruedX128 = 0;
        _stakes[incentiveId][tokenId].liquidity = 0;
        delete _stakes[incentiveId][tokenId];

        // cleaning tokenId storages
        _userTokenIds[msg.sender].remove(tokenId);
        _tokenIds.remove(tokenId);
        _withdrawToken(tokenId, to);
    }

    /** 
    unstakeToken is the real unstake logic entry.
    @notice unstake a LP token and transfer the reward to the LP owner
        [require] deposit existed, means the key and tokenId are both valid
        [effect]  see _cleanReward and _cleanStake
        [interaction] emit TokenUnstaked(incentiveId, tokenId);
    @param key The IncentiveKey struct which defined in IAd3StakeManager, intelnal use only
    @param tokenId The LP token id, intelnal use only
    @param to The target address, intelnal use only
    [return] no return but emit TokenUnstaked(incentiveId, tokenId);
    */
    function unstakeToken(
        IncentiveKey memory key,
        uint256 tokenId,
        address to
    ) external override nonReentrant {
        bytes32 incentiveId = IncentiveId.compute(key);
        Deposit storage deposit = deposits[tokenId];
        Incentive storage incentive = incentives[incentiveId];
        require(deposit.owner == msg.sender, "only owner can unstake token");

        uint256 reward;
        uint160 secondsInsideX128;
        {
            require(
                _stakes[incentiveId][tokenId].liquidity > 0,
                "stake does not exist"
            );

            (, uint160 secondsPerLiquidityInsideX128, ) = key
                .pool
                .snapshotCumulativesInside(
                    deposit.tickLower,
                    deposit.tickUpper
                );
            (reward, secondsInsideX128) = RewardMath.computeRewardAmount(
                incentive.totalRewardUnclaimed,
                incentive.totalSecondsClaimedX128,
                key.startTime,
                key.endTime,
                _stakes[incentiveId][tokenId].liquidity,
                _stakes[incentiveId][tokenId]
                    .secondsPerLiquidityInsideAccruedX128,
                secondsPerLiquidityInsideX128
            );
        }
        {
            _cleanReward(
                deposit,
                incentive,
                reward,
                secondsInsideX128,
                key.rewardToken,
                to
            );
            _cleanStake(incentiveId, tokenId, to);
        }
        emit TokenUnstaked(incentiveId, tokenId);
    }

    //[intraction] transfer the LP token to the operator
    function _withdrawToken(uint256 tokenId, address to) internal {
        require(
            deposits[tokenId].numberOfStakes == 0,
            "nonzero number of stakes"
        );

        delete deposits[tokenId];
        nonfungiblePositionManager.safeTransferFrom(address(this), to, tokenId);
    }

    function getAccruedRewardInfo(IncentiveKey memory key, uint256 tokenId)
        public
        view
        override
        returns (
            uint256 reward,
            uint160 secondsInsideX128,
            uint160 secondsPerLiquidityInsideX128
        )
    {
        bytes32 incentiveId = IncentiveId.compute(key);
        (
            ,
            uint128 liquidity,
            ,
            uint160 secondsPerLiquidityInsideAccruedX128
        ) = stakes(incentiveId, tokenId);

        Incentive storage incentive = incentives[incentiveId];
        require(
            incentive.totalRewardUnclaimed > 0,
            "wrong IncentiveKey, non-existent incentive"
        );
        Deposit storage deposit = deposits[tokenId];
        require(
            deposit.owner != address(0),
            "wrong tokenId, non-existent deposit"
        );
        (, secondsPerLiquidityInsideX128, ) = key
            .pool
            .snapshotCumulativesInside(deposit.tickLower, deposit.tickUpper);

        (reward, secondsInsideX128) = RewardMath.computeRewardAmount(
            incentive.totalRewardUnclaimed,
            incentive.totalSecondsClaimedX128,
            key.startTime,
            key.endTime,
            liquidity,
            secondsPerLiquidityInsideAccruedX128,
            secondsPerLiquidityInsideX128
        );
        reward = deposit.tickUpper < incentive.minTick ? 0 : reward;
    }

    /** 
    claimReward
    @notice transfer some reward from a stake to the specified address
        [require] require(totalReward > 0, "non reward can be claim");
        [require] require(amountRequested > 0 && amountRequested <= totalReward);
        [effect]  rewards[rewardToken][msg.sender] be updated
        [interaction] transfer the reward to specified address
        [interaction] emit RewardClaimed(to, amountRequested);
    @param key The IncentiveKey struct which defined in IAd3StakeManager
    @param tokenId The LP token id
    @param to The target address
    @param amountRequested The amount of reward to be claimed
    [return] no return but emit RewardClaimed(to, amountRequested);
    */
    function claimReward(
        IncentiveKey memory key,
        uint256 tokenId,
        address to,
        uint256 amountRequested
    ) external override nonReentrant {
        bytes32 incentiveId = IncentiveId.compute(key);
        address rewardToken = key.rewardToken;
        uint256 totalReward = rewards[rewardToken][msg.sender];
        (
            uint256 reward,
            uint160 secondsInsideX128,
            uint160 secondsPerLiquidityInsideX128
        ) = getAccruedRewardInfo(key, tokenId);
        if (reward > 0) {
            Incentive storage incentive = incentives[incentiveId];
            incentive.totalSecondsClaimedX128 = uint160(
                SafeMath.add(
                    incentive.totalSecondsClaimedX128,
                    secondsInsideX128
                )
            );
            incentive.totalRewardUnclaimed = incentive.totalRewardUnclaimed.sub(
                reward
            );
            totalReward = totalReward.add(reward);
        }
        require(totalReward > 0, "non reward can be claim");
        require(amountRequested > 0 && amountRequested <= totalReward);

        rewards[rewardToken][msg.sender] = totalReward.sub(amountRequested);
        TransferHelper.safeTransfer(rewardToken, to, amountRequested);

        Stake storage stake = _stakes[incentiveId][tokenId];
        stake
            .secondsPerLiquidityInsideAccruedX128 = secondsPerLiquidityInsideX128;

        emit RewardClaimed(to, amountRequested);
    }
}
