// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

import './interfaces/harvest/IChef.sol';
import './interfaces/harvest/IConverter.sol';
import './interfaces/pickle/IMiniChefV2.sol';
import './interfaces/pickle/IJar.sol';

contract Harvester is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using Address for address;

    // pickle token itself
    IERC20 public pickle;

    // chef rewards pickles, essentially manages the farms
    IMiniChefV2 public chef; // todo: make this IChef

    // Handles converting from a token (usually pickles) to the
    // jar's wanted token.
    mapping(address => mapping(address => address)) converters;

    // Initialize functions
    function initialize(address _pickle, address _chef) public initializer {
        require(_pickle != address(0), "Pickle can't be null address.");
        require(_chef != address(0), "Chef can't be null address.");

        __Ownable_init();

        pickle = IERC20(_pickle);
        chef = IMiniChefV2(_chef);
    }

    // External functions

    function setChef(address _chef) external onlyOwner {
        require(_chef != address(0), "Chef can't be null address.");
        chef = IMiniChefV2(_chef);
    }

    function setConverter(
        address _input, 
        address _output, 
        address _converter
    ) external onlyOwner {
        converters[_input][_output] = _converter;
    }

    /// @notice harvest from a farm and reinvest back into
    /// the jar / farm
    function harvest(uint256 _pid, address _jar) external {
        harvest(_pid, _pid, _jar);
    }

    // Public functions

    /// @notice harvest pickles from a farm, convert them, and 
    /// deposit into another jar & farm
    /// @param _fromId the chef pool id of the farm to harvest
    /// pickles from.
    /// @param _toId the chef pool id of the farm to deposit
    /// new pickled tokens
    /// @param _to the jar to deposit the harvested pickles into
    function harvest(
        uint256 _fromId, 
        uint256 _toId, 
        address _to,
        bytes memory _harvestTx
    ) public {
        uint256 _fromBal = chef.pendingPickle(_fromId, msg.sender);
        require(_fromBal > 0, "No pickles to harvest.");

        // this won't work because harvest will use the
        // balance of msg.sender which will be the contract
        // chef.harvest(_fromId, address(this));

        Address.functionCall(address(chef), _harvestTx);

        IJar _jar = IJar(_to);
        address _want = _jar.token();
        uint256 _wantBal = 0;

        if (_hasConverter(_want)) {
            _wantBal = _convert(_want, _fromBal);
        }

        require(_wantBal > 0, "Don't have wanted tokens.");

        uint256 _pBeforeBal = _jar.balanceOf(address(this));
        _jar.deposit(_wantBal);
        uint256 _pAfterBal = _jar.balanceOf(address(this));
        uint256 _pBal = _pAfterBal - _pBeforeBal;

        require(_pBal > 0, "Didn't receive pickled tokens from jar.");

        chef.deposit(_toId, _pBal, msg.sender);
    }

    // Internal functions

    function _convert(address _to, uint256 _amount) internal returns (uint256) {
        return _convert(address(pickle), _to, _amount);
    }

    function _convert(address _from, address _to, uint256 _amount) internal returns (uint256) {
        address _cnvrtr = converters[_from][_to];

        IERC20(_from).safeApprove(_cnvrtr, 0);
        IERC20(_from).safeApprove(_cnvrtr, _amount);

        uint256 _beforeBal = IERC20(_to).balanceOf(address(this));

        IConverter(_cnvrtr).convert(_amount);

        uint256 _bal = IERC20(_to).balanceOf(address(this));
        require(_bal > _beforeBal, "Did not receive want tokens after conversion.");

        return _bal - _beforeBal;
    }

    function _deposit(uint256 _pid, IJar _jar, uint256 _wantBal) internal {
        

    }

    // Internal view functions

    function _hasConverter(address _out) internal view returns (bool) {
        return _hasConverter(address(pickle), _out);
    }

    function _hasConverter(address _in, address _out) internal view returns (bool) {
        return converters[_in][_out] != address(0);
    }
}