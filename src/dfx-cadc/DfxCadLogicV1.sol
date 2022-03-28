// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../interfaces/IDfxOracle.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./DfxCadcState.sol";

import "../libraries/FullMath.sol";

contract DfxCadLogicV1 is DfxCadcState {
    using SafeERC20 for IERC20;

    // **** Initializing functions ****

    // We don't need the old initialize logic as the state has
    // already been set, this is just to change the name + symbol
    function initialize() public {
        // Don't initialize twice
        require(keccak256(bytes(name())) == keccak256(bytes("dfxCADC")), "no-reinit");

        // Assign new name and symbol
        _name = "dfxCAD";
        _symbol = "dfxCAD";
    }

    // **** Modifiers ****

    modifier updatePokes() {
        // Make sure we can poke
        require(
            block.timestamp > lastPokeTime + POKE_WAIT_PERIOD,
            "invalid-poke-time"
        );

        _;

        // Sanity checks
        require(
            dfxRatio > 0 &&
                dfxRatio < 1e18 &&
                cadcRatio > 0 &&
                cadcRatio < 1e18,
            "invalid-ratios"
        );

        lastPokeTime = block.timestamp;
    }

    // **** Restricted functions ****

    // Sets the 'poke' delta
    /// @notice Manually sets the delta between each poke
    /// @param _pokeRatioDelta The delta between each poke, 100% = 1e18.
    function setPokeDelta(uint256 _pokeRatioDelta) public onlyRole(SUDO_ROLE) {
        require(
            _pokeRatioDelta <= MAX_POKE_RATIO_DELTA,
            "poke-ratio-delta: too big"
        );
        pokeRatioDelta = _pokeRatioDelta;
    }

    /// @notice Used when market price / TWAP is > than backing.
    ///         If set correctly, the underlying backing of the stable
    ///         assets will decrease and the underlying backing of the volatile
    ///         assets will increase.
    function pokeUp() public onlyRole(POKE_ROLE) updatePokes {
        dfxRatio = dfxRatio + pokeRatioDelta;
        cadcRatio = cadcRatio - pokeRatioDelta;
    }

    /// @notice Used when market price / TWAP is < than backing.
    ///         If set correctly, the underlying backing of the stable
    ///         assets will increase and the underlying backing of the volatile
    ///         assets will decrease
    function pokeDown() public onlyRole(POKE_ROLE) updatePokes {
        dfxRatio = dfxRatio - pokeRatioDelta;
        cadcRatio = cadcRatio + pokeRatioDelta;
    }

    /// @notice Sets the TWAP address
    function setDfxCadTwap(address _dfxCadTwap) public onlyRole(SUDO_ROLE) {
        dfxCadTwap = _dfxCadTwap;
    }

    /// @notice Sets the fee recipient for mint/burn
    function setFeeRecipient(address _recipient) public onlyRole(SUDO_ROLE) {
        feeRecipient = _recipient;
    }

    /// @notice In case anyone sends tokens to the wrong address
    function recoverERC20(address _a) public onlyRole(SUDO_ROLE) {
        require(_a != DFX && _a != CADC, "no");
        IERC20(_a).safeTransfer(
            msg.sender,
            IERC20(_a).balanceOf(address(this))
        );
    }

    /// @notice Sets mint/burn fee
    function setMintBurnFee(uint256 _f) public onlyRole(SUDO_ROLE) {
        require(_f < 1e18, "invalid-fee");
        mintBurnFee = _f;
    }

    /// @notice Emergency trigger
    function setPaused(bool _p) public onlyRole(SUDO_ROLE) {
        if (_p) {
            _pause();
        } else {
            _unpause();
        }
    }

    /// @notice Execute functionality used to perform buyback and recollateralization
    function execute(address _target, bytes memory _data)
        public
        onlyRole(CR_DEFENDER)
        returns (bytes memory response)
    {
        require(_target != address(0), "target-address-required");

        // call contract in current context
        assembly {
            let succeeded := delegatecall(
                sub(gas(), 5000),
                _target,
                add(_data, 0x20),
                mload(_data),
                0,
                0
            )
            let size := returndatasize()

            response := mload(0x40)
            mstore(
                0x40,
                add(response, and(add(add(size, 0x20), 0x1f), not(0x1f)))
            )
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
            case 1 {
                // throw if delegatecall failed
                revert(add(response, 0x20), size)
            }
        }
    }

    // **** Public stateful functions ****

    /// @notice Mints the ASC token
    /// @param _amount Amount of ASC token to mint
    function mint(uint256 _amount) public nonReentrant whenNotPaused {
        require(_amount > 0, "non-zero only");

        (uint256 cadcAmount, uint256 dfxAmount) = getUnderlyings(_amount);
        IERC20(CADC).safeTransferFrom(msg.sender, address(this), cadcAmount);
        IERC20(DFX).safeTransferFrom(msg.sender, address(this), dfxAmount);

        // No fee for market makers
        if (hasRole(MARKET_MAKER_ROLE, msg.sender)) {
            _mint(msg.sender, _amount);
        } else {
            uint256 _fee = (_amount * mintBurnFee) / 1e18;
            _mint(msg.sender, _amount - _fee);
            _mint(feeRecipient, _fee);
        }
    }

    /// @notice Burns the ASC token
    /// @param _amount Amount of ASC token to burn
    function burn(uint256 _amount) public nonReentrant whenNotPaused {
        require(_amount > 0, "non-zero only");

        // No fee for market makers
        if (hasRole(MARKET_MAKER_ROLE, msg.sender)) {
            _burn(msg.sender, _amount);
        } else {
            uint256 _fee = (_amount * mintBurnFee) / 1e18;
            _burn(msg.sender, _amount);
            _mint(feeRecipient, _fee);
            _amount = _amount - _fee;
        }

        (uint256 cadcAmount, uint256 dfxAmount) = getUnderlyings(_amount);
        IERC20(CADC).safeTransfer(msg.sender, cadcAmount);
        IERC20(DFX).safeTransfer(msg.sender, dfxAmount);
    }

    // **** View only functions ****

    /// @notice Get the underlyings of `_amount` of 'logic' tokens
    ///         For example, how many underlyings will `_amount` token yield?
    ///         Or, how many underlyings do I need to mint `_amount` token?
    /// @param _amount The amount of 'logic' token
    function getUnderlyings(uint256 _amount)
        public
        view
        returns (uint256 cadcAmount, uint256 dfxAmount)
    {
        uint256 cadPerDfx = IDfxOracle(dfxCadTwap).read();

        cadcAmount = FullMath.mulDivRoundingUp(_amount, cadcRatio, 1e18);
        dfxAmount = FullMath.mulDivRoundingUp(_amount, dfxRatio, 1e18);
        dfxAmount = FullMath.mulDivRoundingUp(dfxAmount, 1e18, cadPerDfx);
    }
}
