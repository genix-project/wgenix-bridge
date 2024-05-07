// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

contract Genix is ERC20 {
    uint256 public constant maxSupply = 210_000_000e8;
    uint8 private _decimals;
    uint256 private _chainId;

    address[] private _authorityAddresses;
    uint256 private _authorityThreshold;
    uint256 private _configurationNonce;

    mapping(address => mapping(string => uint256)) private _mintHistory;
    mapping(address => uint256) private _mintNonce;

    constructor() ERC20("Genix", "GENIX") {
        _decimals = 8;
        _chainId = 56;

        _authorityAddresses = [
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000002
        ];
        _authorityThreshold = 2;
        _configurationNonce = 0;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function _verifyAuthority(
        bytes32 dataHash,
        uint8[] calldata signV,
        bytes32[] calldata signR,
        bytes32[] calldata signS
    ) private view {
        bytes32 prefixedHash = keccak256(
            abi.encodePacked(
                bytes("\x19Ethereum Signed Message:\n32"),
                dataHash
            )
        );
        uint256 signatures = 0;
        for (uint256 i = 0; i < _authorityAddresses.length; i++) {
            if (
                ecrecover(prefixedHash, signV[i], signR[i], signS[i]) ==
                _authorityAddresses[i]
            ) {
                signatures++;
            }
            if (signatures >= _authorityThreshold) {
                break;
            }
        }
        require(signatures >= _authorityThreshold);
    }

    function authorityAddresses() external view returns (address[] memory) {
        return _authorityAddresses;
    }

    function authorityThreshold() external view returns (uint256) {
        return _authorityThreshold;
    }

    function configurationNonce() external view returns (uint256) {
        return _configurationNonce;
    }

    function configure(
        address[] calldata newAuthorityAddresses,
        uint256 newAuthorityThreshold,
        uint8[] calldata signV,
        bytes32[] calldata signR,
        bytes32[] calldata signS
    ) external {
        require(newAuthorityAddresses.length >= 1);
        require(newAuthorityThreshold >= 1);
        require(signV.length == _authorityAddresses.length);
        require(signR.length == _authorityAddresses.length);
        require(signS.length == _authorityAddresses.length);

        _verifyAuthority(
            keccak256(
                abi.encode(
                    _chainId,
                    _configurationNonce,
                    newAuthorityAddresses,
                    newAuthorityThreshold
                )
            ),
            signV,
            signR,
            signS
        );

        _configurationNonce++;
        _authorityAddresses = newAuthorityAddresses;
        _authorityThreshold = newAuthorityThreshold;
    }

    function mintNonce(address addr) external view returns (uint256) {
        return _mintNonce[addr];
    }

    function mintHistory(address addr, string calldata depositAddress)
        external
        view
        returns (uint256, uint256)
    {
        return (_mintNonce[addr], _mintHistory[addr][depositAddress]);
    }

    function mint(
        string calldata depositAddress,
        uint256 amount,
        uint8[] calldata signV,
        bytes32[] calldata signR,
        bytes32[] calldata signS
    ) external {
        require(signV.length == _authorityAddresses.length);
        require(signR.length == _authorityAddresses.length);
        require(signS.length == _authorityAddresses.length);

        _verifyAuthority(
            keccak256(
                abi.encode(
                    _chainId,
                    _msgSender(),
                    _mintNonce[_msgSender()],
                    depositAddress,
                    amount
                )
            ),
            signV,
            signR,
            signS
        );
        require(amount + totalSupply() <= maxSupply, "!MAX_SUPPLY");
        _mint(_msgSender(), amount);
        _mintNonce[_msgSender()]++;
        _mintHistory[_msgSender()][depositAddress] += amount;
    }
}
