// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./State.sol";

contract Logic is State {
    using SafeERC20 for IERC20;

    // **** Initializing functions ****

    // We don't need to check twice if the contract's initialized as
    // __ERC20_init does that check
    function initialize(
        string memory _name,
        string memory _symbol,
        address _admin,
        address _feeRecipient,
        uint256 _mintBurnFee,
        address[] memory _underlying,
        uint256[] memory _underlyingPerToken,
        int256[] memory _pokeDelta
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __ReentrancyGuard_init();

        _setRoleAdmin(SUDO_ROLE, SUDO_ROLE_ADMIN);
        _setupRole(SUDO_ROLE_ADMIN, _admin);
        _setupRole(SUDO_ROLE, _admin);

        _setRoleAdmin(MARKET_MAKER_ROLE, MARKET_MAKER_ROLE_ADMIN);
        _setupRole(MARKET_MAKER_ROLE_ADMIN, _admin);
        _setupRole(MARKET_MAKER_ROLE, _admin);

        _setRoleAdmin(POKE_ROLE, POKE_ROLE_ADMIN);
        _setupRole(POKE_ROLE_ADMIN, _admin);
        _setupRole(POKE_ROLE, _admin);

        underlying = _underlying;
        underlyingPerToken = _underlyingPerToken;
        pokeDelta = _pokeDelta;
        feeRecipient = _feeRecipient;
        mintBurnFee = _mintBurnFee;

        // Sanity checks, no SLOAD woot
        // We gas golfing here
        require(
            _underlying.length == _underlyingPerToken.length,
            "invalid-underlyings"
        );
    }

    // **** Modifiers ****

    modifier updatePokeTime() {
        require(
            block.timestamp > lastPokeTime + POKE_WAIT_PERIOD,
            "invalid-poke-time"
        );

        _;

        lastPokeTime = block.timestamp;
    }

    // **** Restricted functions ****

    // Sets the 'poke' delta
    /// @notice Manually sets the delta between each poke
    /// @param _deltas The delta between each poke, in 1e18.
    ///                For example, delta of [1e16, -1e16] and underlying of [5e17, 5e17]
    ///                the backingRatio will become [51e16, 49e16] when pokedUp and
    ///                [49e16, 51e16] when pokedDown
    function setPokeDelta(int256[] memory _deltas) public onlyRole(SUDO_ROLE) {
        require(_deltas.length == underlying.length, "invalid-delta-length");
        pokeDelta = _deltas;
    }

    /// @notice Used when market price / TWAP is > than backing.
    ///         If set correctly, the underlying backing of the stable
    ///         assets will decrease and the underlying backing of the volatile
    ///         assets will increase.
    function pokeUp() public onlyRole(POKE_ROLE) updatePokeTime {
        for (uint256 i = 0; i < underlyingPerToken.length; i++) {
            underlyingPerToken[i] = uint256(
                int256(underlyingPerToken[i]) + pokeDelta[i]
            );
        }
    }

    /// @notice Used when market price / TWAP is < than backing.
    ///         If set correctly, the underlying backing of the stable
    ///         assets will increase and the underlying backing of the volatile
    ///         assets will decrease
    function pokeDown() public onlyRole(POKE_ROLE) updatePokeTime {
        for (uint256 i = 0; i < underlyingPerToken.length; i++) {
            underlyingPerToken[i] = uint256(
                int256(underlyingPerToken[i]) - pokeDelta[i]
            );
        }
    }

    /// @notice Sets the fee recipient for mint/burn
    function setFeeRecipient(address _recipient) public onlyRole(SUDO_ROLE) {
        feeRecipient = _recipient;
    }

    /// @notice In case anyone sends tokens to the wrong address
    function recoverERC20(address _a) public onlyRole(SUDO_ROLE) {
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

    // **** Public stateful functions ****

    /// @notice Mints the ASC token
    /// @param _amount Amount of ASC token to mint
    function mint(uint256 _amount) public nonReentrant whenNotPaused {
        require(_amount > 0, "non-zero only");

        uint256[] memory _amounts = getUnderlyings(_amount);

        for (uint256 i = 0; i < underlying.length; i++) {
            IERC20(underlying[i]).safeTransferFrom(
                msg.sender,
                address(this),
                _amounts[i]
            );
        }

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

        uint256[] memory _amounts = getUnderlyings(_amount);
        for (uint256 i = 0; i < underlying.length; i++) {
            IERC20(underlying[i]).safeTransfer(msg.sender, _amounts[i]);
        }
    }

    // **** View only functions ****

    /// @notice Get the underlyings of `_amount` of 'logic' tokens
    ///         For example, how many underlyings will `_amount` token yield?
    ///         Or, how many underlyings do I need to mint `_amount` token?
    /// @param _amount The amount of 'logic' token
    function getUnderlyings(uint256 _amount)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory _amounts = new uint256[](underlying.length);

        for (uint256 i = 0; i < underlying.length; i++) {
            _amounts[i] = (_amount * underlyingPerToken[i]) / 1e18;
        }

        return _amounts;
    }
}
