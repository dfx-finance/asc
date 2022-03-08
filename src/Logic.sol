// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./State.sol";

contract Logic is State {
    using SafeERC20 for IERC20;

    constructor(
        string memory _name,
        string memory _symbol,
        address _admin,
        address _feeRecipient,
        address[] memory _underlying,
        uint256[] memory _backingRatio,
        int256[] memory _pokeDelta
    ) {
        __ERC20_init(_name, _symbol);

        _setRoleAdmin(SUDO_ROLE, SUDO_ROLE_ADMIN);
        _setupRole(SUDO_ROLE_ADMIN, _admin);
        _setupRole(SUDO_ROLE, _admin);

        _setRoleAdmin(MARKET_MAKER_ROLE, MARKET_MAKER_ROLE_ADMIN);
        _setupRole(MARKET_MAKER_ROLE_ADMIN, _admin);
        _setupRole(MARKET_MAKER_ROLE, _admin);

        underlying = _underlying;
        backingRatio = _backingRatio;
        pokeDelta = _pokeDelta;
        feeRecipient = _feeRecipient;
    }

    // **** Modifiers ****

    modifier validBackingRatios() {
        _;

        uint256 i = 0;
        for (uint256 j = 0; j < backingRatio.length; j++) {
            i = i + backingRatio[j];
        }
        require(i == 1e18, "invalid-backing-ratio");
    }

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
        require(_deltas.length == backingRatio.length, "invalid-delta-length");
        pokeDelta = _deltas;
    }

    /// @notice Used when market price / TWAP is > than backing.
    ///         If set correctly, the backing ratio of the stable
    ///         assets will decrease and the backing ratio of the volatile
    ///         assets will increase.
    function pokeUp()
        public
        onlyRole(SUDO_ROLE)
        validBackingRatios
        updatePokeTime
    {
        for (uint256 i = 0; i < backingRatio.length; i++) {
            backingRatio[i] = uint256(int256(backingRatio[i]) + pokeDelta[i]);
        }
    }

    /// @notice Used when market price / TWAP is < than backing.
    ///         If set correctly, the backing ratio of the stable
    ///         assets will increase and the backing ratio of the volatile
    ///         assets will decrease
    function pokeDown()
        public
        onlyRole(SUDO_ROLE)
        validBackingRatios
        updatePokeTime
    {
        for (uint256 i = 0; i < backingRatio.length; i++) {
            backingRatio[i] = uint256(int256(backingRatio[i]) - pokeDelta[i]);
        }
    }

    /// @notice Sets the fee recipient for mint/burn
    function setFeeRecipient(address _recipient) public onlyRole(SUDO_ROLE) {
        feeRecipient = _recipient;
    }

    // **** Public stateful functions ****

    /// @notice Mints the ASC token
    /// @param _amount Amount of ASC token to mint
    function mint(uint256 _amount) public nonReentrant {
        require(_amount > 0, "non-zero only");

        uint256[] memory _amounts = getMintUnderlyings(_amount);

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
            uint256 _fee = (_amount * MINT_BURN_FEE) / 1e18;
            _mint(msg.sender, _amount - _fee);
            _mint(feeRecipient, _fee);
        }
    }

    /// @notice Burns the ASC token
    /// @param _amount Amount of ASC token to burn
    function burn(uint256 _amount) public nonReentrant {
        require(_amount > 0, "non-zero only");

        // No fee for market makers
        if (hasRole(MARKET_MAKER_ROLE, msg.sender)) {
            _burn(msg.sender, _amount);
        } else {
            uint256 _fee = (_amount * MINT_BURN_FEE) / 1e18;
            _burn(msg.sender, _amount);
            _mint(feeRecipient, _fee);
            _amount = _amount - _fee;
        }

        uint256[] memory _amounts = getMintUnderlyings(_amount);
        for (uint256 i = 0; i < underlying.length; i++) {
            if (msg.sender == feeRecipient) {
                IERC20(underlying[i]).safeTransfer(msg.sender, _amounts[i]);
            } else {}
        }
    }

    // **** View only functions ****

    function getMintUnderlyings(uint256 _mintAmount)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory _amounts = new uint256[](underlying.length);

        for (uint256 i = 0; i < underlying.length; i++) {
            uint256 _totalUnderlyingAmount = IERC20(underlying[i]).balanceOf(
                address(this)
            );

            // How many underlying per mint amount
            uint256 _singleton = (_totalUnderlyingAmount * 1e18) /
                backingRatio[i];

            _amounts[i] = (_singleton * _mintAmount) / 1e18;
        }

        return _amounts;
    }
}
