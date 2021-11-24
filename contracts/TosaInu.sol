// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";

import "./Blacklist.sol";

enum Entity {
    Seller,
    Buyer
}

contract TosaInu is IERC20, IERC20Metadata, Pausable, Ownable, BlackList {
    //***************************************** Events *****************************************
    event LogLiquidityEvent(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );

    event LogLiquidityEventState(bool state);

    //***************************************** State Variables *****************************************

    //***************************************** Public *****************************************
    string private _name = "Tosa Inu";

    string private _symbol = "TOSA";

    uint8 private _decimals = 18;

    IUniswapV2Router02 public uniswapV2Router;

    address public uniswapV2WETHPair;

    address public marketingFund;

    address public presaleContract;

    uint256 public totalFees;

    uint256 public buyerReflectionTax;

    uint256 public buyerLiquidityTax;

    uint256 public buyerMarketingTax;

    uint256 public sellerReflectionTax = 1; // 1%

    uint256 public sellerLiquidityTax = 3; // 3%

    uint256 public sellerMarketingTax = 2; // 2%

    bool public liquidityEventInProgress;

    bool public liquidityEvenState;

    //@dev 0.5% of total supply can be transferred at once
    uint256 public maxWalletAmount = 5 * 10**6 * 10**18;

    //@dev 0.2% of total supply can be transferred at once
    uint256 public maxTxAmount = 2 * 10**6 * 10**18;

    //***************************************** Private *****************************************
    uint256 private constant MAX_INT_VALUE = type(uint256).max;

    uint256 private _totalSupply = 10**9 * 10**18;

    uint256 private _reflectionSupply =
        MAX_INT_VALUE - (MAX_INT_VALUE % _totalSupply);

    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => uint256) private _reflectionBalance;

    mapping(address => bool) private _isWhitelisted;

    mapping(address => bool) private _isBlackListed;

    uint256 private _deadBlocks;

    uint256 private _launchedAt;

    //@dev once the contract holds 0.5% it will trigger a liquidity event
    uint256 private constant _numberTokensSellToAddToLiquidity =
        5 * 10**6 * 10**18;

    constructor(address _router, address _marketingFund) {
        //@notice Give all supply to owner
        _reflectionBalance[_msgSender()] = _reflectionSupply;

        //@notice Tells solidity this address is the router
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_router);

        //@dev creates the market for WBNB/TOSA
        uniswapV2WETHPair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        //@notice Assign PCS V2 router
        uniswapV2Router = _uniswapV2Router;

        marketingFund = _marketingFund;

        _isWhitelisted[_msgSender()] = true;
        _isWhitelisted[address(this)] = true;
        _isWhitelisted[_marketingFund] = true;

        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    //***************************************** modifiers *****************************************
    //@dev security prevents swapping during a liquidity event
    modifier lockSwap() {
        liquidityEventInProgress = true;
        _;
        liquidityEventInProgress = false;
    }

    //***************************************** private functions *****************************************

    //@dev returns the convetion rate between reflection to token
    function _getRate() private view returns (uint256) {
        return _reflectionSupply / _totalSupply;
    }

    //@dev converts an amount of token to reflections
    function _getReflectionsFromTokens(uint256 _amount)
        private
        view
        returns (uint256)
    {
        require(_totalSupply >= _amount, "TOSA: convert less tokens");
        return _amount * _getRate();
    }

    //@dev converts an amount of reflections to tokens
    function _getTokensFromReflections(uint256 _amount)
        private
        view
        returns (uint256)
    {
        require(_reflectionSupply >= _amount, "TOSA: convert less reflections");
        return _amount / _getRate();
    }

    //@dev assumes that _tax = 5 means 5%
    function _calculateTax(uint256 _amount, uint256 _tax)
        private
        pure
        returns (uint256)
    {
        return (_amount * _tax) / 100;
    }

    //@dev buys ETH with tokens stored in this contract
    function _swapTokensForEth(uint256 _amount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), _amount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _amount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    //@dev Adds equal amount of eth and tokens to the ETH liquidity pool
    function _addLiquidity(uint256 _tokenAmount, uint256 _ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), _tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: _ethAmount}(
            address(this),
            _tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function _swapAndLiquefy() private lockSwap {
        // split the contract token balance into halves
        uint256 half = _numberTokensSellToAddToLiquidity / 2;
        uint256 otherHalf = _numberTokensSellToAddToLiquidity - half;

        uint256 initialETHContractBalance = address(this).balance;

        // Buys ETH at current token price
        _swapTokensForEth(half);

        // This is to make sure we are only using ETH derived from the liquidity fee
        uint256 ethBought = address(this).balance - initialETHContractBalance;

        // Add liquidity to the pool
        _addLiquidity(otherHalf, ethBought);

        emit LogLiquidityEvent(half, ethBought, otherHalf);
    }

    function _approve(
        address _owner,
        address _beneficiary,
        uint256 _amount
    ) private {
        require(
            _beneficiary != address(0),
            "The burn address is not allowed to receive approval for allowances."
        );
        require(
            _owner != address(0),
            "The burn address is not allowed to approve allowances."
        );

        _allowances[_owner][_beneficiary] = _amount;
        emit Approval(_owner, _beneficiary, _amount);
    }

    function _send(
        address _sender,
        address _recipient,
        uint256 _amount
    ) private {
        uint256 rAmount = _getReflectionsFromTokens(_amount);

        _reflectionBalance[_sender] -= rAmount;

        _reflectionBalance[_recipient] += rAmount;

        emit Transfer(_sender, _recipient, _amount);
    }

    function _whitelistSend(
        address _sender,
        address _recipient,
        uint256 _amount
    ) private whenNotPaused {
        _send(_sender, _recipient, _amount);
    }

    function _sendWithTax(
        address _sender,
        address _recipient,
        uint256 _amount,
        // These are percentages
        uint256 _reflectionTax,
        uint256 _liquidityTax,
        uint256 _marketingTax
    ) private whenNotPaused {
        uint256 rAmount = _getReflectionsFromTokens(_amount);

        if (_recipient != uniswapV2WETHPair) {
            require(
                _getTokensFromReflections(
                    _reflectionBalance[_recipient] + rAmount
                ) <= maxWalletAmount,
                "TOSA: there is a max wallet limit"
            );
        }

        _reflectionBalance[_sender] -= rAmount;

        //@dev convert the % to the nominal amount
        uint256 liquidityTax = _calculateTax(_amount, _liquidityTax);
        //@dev convert from tokens to reflections to update balances
        uint256 rLiquidityTax = _getReflectionsFromTokens(liquidityTax);

        uint256 marketingTax = _calculateTax(_amount, _marketingTax);
        uint256 rMarketingTax = _getReflectionsFromTokens(marketingTax);

        uint256 reflectionTax = _calculateTax(_amount, _reflectionTax);
        uint256 rReflectionTax = _getReflectionsFromTokens(reflectionTax);

        _reflectionBalance[_recipient] +=
            rAmount -
            rLiquidityTax -
            rMarketingTax -
            rReflectionTax;

        _reflectionBalance[marketingFund] += rMarketingTax;

        _reflectionBalance[address(this)] += rLiquidityTax;

        _reflectionSupply -= rReflectionTax;

        totalFees += liquidityTax + marketingTax + reflectionTax;

        uint256 finalAmount = _amount -
            reflectionTax -
            marketingTax -
            liquidityTax;

        emit Transfer(_sender, _recipient, finalAmount);
    }

    function _sell(
        address _sender,
        address _recipient,
        uint256 _amount
    ) private {
        _sendWithTax(
            _sender,
            _recipient,
            _amount,
            sellerReflectionTax,
            //@dev blacklisted seller will be punished with most of his tokens going to the liquidity
            isBlacklisted(_sender) ? 95 : sellerLiquidityTax,
            sellerMarketingTax
        );
    }

    function _buy(
        address _sender,
        address _recipient,
        uint256 _amount
    ) private {
        _sendWithTax(
            _sender,
            _recipient,
            _amount,
            buyerReflectionTax,
            buyerLiquidityTax,
            buyerMarketingTax
        );
    }

    function _transfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) private {
        require(
            _sender != address(0),
            "TOSA: Sender cannot be the zero address"
        );
        require(
            _recipient != address(0),
            "TOSA: Recipient cannot be the zero address"
        );
        require(_amount > 0, "TOSA: amount cannot be zero");

        if (!_isWhitelisted[_sender]) {
            require(_amount <= maxTxAmount, "TOSA: amount exceeds the limit");
        }

        // Condition 1: Make sure the contract has the enough tokens to liquefy
        // Condition 2: We are not in a liquefication event
        // Condition 3: Liquification is enabled
        // Condition 4: It is not the uniswapPair that is sending tokens

        if (
            balanceOf(address(this)) >= _numberTokensSellToAddToLiquidity &&
            !liquidityEventInProgress &&
            liquidityEvenState &&
            _sender != uniswapV2WETHPair
        ) _swapAndLiquefy();

        //@dev presaleContract can send tokens even when the contract is paused
        if (_sender == presaleContract || _recipient == presaleContract) {
            _send(_sender, _recipient, _amount);
            return;
        }

        //@dev whitelisted addresses can transfer without fees and no limit on their hold (marketingFund/Owner)
        if (_isWhitelisted[_sender] || _isWhitelisted[_recipient]) {
            _whitelistSend(_sender, _recipient, _amount);
            return;
        }

        //@dev snipers will be caught on buying and punished on selling
        if (block.number <= _launchedAt + _deadBlocks) {
            _addToBlacklist(_recipient);
        }

        //@dev if tokens are being sent to PCS pair/router it represents a sell swap
        if (
            _recipient == address(uniswapV2Router) ||
            _recipient == address(uniswapV2WETHPair)
        ) {
            _sell(_sender, _recipient, _amount);
        } else {
            _buy(_sender, _recipient, _amount);
        }
    }

    //***************************************** public functions *****************************************

    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     *@dev It returns the symbol of the token.
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     *@dev It returns the decimal of the token.
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    //@dev It is necessary to convert from reflections to tokens to display the proper balance
    function balanceOf(address _account)
        public
        view
        override
        returns (uint256)
    {
        return _getTokensFromReflections(_reflectionBalance[_account]);
    }

    function approve(address _beneficiary, uint256 _amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), _beneficiary, _amount);
        return true;
    }

    function transfer(address _recipient, uint256 _amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), _recipient, _amount);
        return true;
    }

    function allowance(address _owner, address _beneficiary)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[_owner][_beneficiary];
    }

    function increaseAllowance(address _beneficiary, uint256 _amount)
        external
        returns (bool)
    {
        _approve(
            _msgSender(),
            _beneficiary,
            _allowances[_msgSender()][_beneficiary] + _amount
        );
        return true;
    }

    function decreaseAllowance(address _beneficiary, uint256 _amount)
        external
        returns (bool)
    {
        _approve(
            _msgSender(),
            _beneficiary,
            _allowances[_msgSender()][_beneficiary] - _amount
        );
        return true;
    }

    function transferFrom(
        address _provider,
        address _beneficiary,
        uint256 _amount
    ) public override returns (bool) {
        _transfer(_provider, _beneficiary, _amount);
        _approve(
            _provider,
            _msgSender(),
            _allowances[_provider][_msgSender()] - _amount
        );
        return true;
    }

    //***************************************** Owner only functions *****************************************

    function launch(uint256 _amount) external onlyOwner {
        require(_launchedAt == 0, "TOSA: already launched");
        _launchedAt = block.number;
        _deadBlocks = _amount;
        _unpause();
    }

    function addToBlacklist(address _account) external onlyOwner {
        require(_account != address(0), "TOSA: zero address");
        _addToBlacklist(_account);
    }

    function removeFromBlacklist(address _account) external onlyOwner {
        require(_account != address(0), "TOSA: zero address");
        _removeFromBlacklist(_account);
    }

    function setPresaleContract(address _account) external onlyOwner {
        require(presaleContract == address(0), "TOSA: already set!");
        presaleContract = _account;
    }

    function toggleLiquidityEventState() external onlyOwner {
        liquidityEvenState = !liquidityEvenState;
        emit LogLiquidityEventState(liquidityEvenState);
    }

    function withdrawETH() external onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}(
            ""
        );
        require(success, "TOSA: failed to send ETH");
    }

    function setMaxTxAmount(uint256 _amount) external onlyOwner {
        maxTxAmount = _amount;
    }

    function setMaxWalletAmount(uint256 _amount) external onlyOwner {
        maxWalletAmount = _amount;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function addToWhiteList(address _account) external onlyOwner {
        _isWhitelisted[_account] = true;
    }

    function removeFromWhitelist(address _account) external onlyOwner {
        _isWhitelisted[_account] = false;
    }

    function setTax(
        Entity _entity,
        uint256 _liquidityTax,
        uint256 _marketingTax,
        uint256 _reflectionTax
    ) external onlyOwner {
        if (_entity == Entity.Buyer) {
            buyerLiquidityTax = _liquidityTax;
            buyerMarketingTax = _marketingTax;
            buyerReflectionTax = _reflectionTax;
        } else {
            sellerLiquidityTax = _liquidityTax;
            sellerMarketingTax = _marketingTax;
            sellerReflectionTax = _reflectionTax;
        }
    }

    function updateRouter(address _router) external onlyOwner {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_router);

        address pair = IUniswapV2Factory(_uniswapV2Router.factory()).getPair(
            address(this),
            _uniswapV2Router.WETH()
        );

        if (pair == address(0)) {
            pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
                address(this),
                _uniswapV2Router.WETH()
            );
        }

        uniswapV2WETHPair = pair;
        uniswapV2Router = _uniswapV2Router;
    }

    function setMarketingFund(address _account) external onlyOwner {
        marketingFund = _account;
    }

    function withdrawERC20(address _token, address _to)
        external
        onlyOwner
        returns (bool)
    {
        require(
            _token != address(this),
            "You cannot withdraw this contract tokens."
        );
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        require(
            IERC20(_token).transfer(_to, _contractBalance),
            "TOSA: failed to send ERC20"
        );
        return true;
    }

    //@dev receive ETHER from the PCS
    receive() external payable {}
}
