// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice tokens
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title dEvoting NFT
 * @author Ghadi Mhawej
 **/

contract dEvotingNFT is ERC1155, ERC1155Supply, Pausable {
    /// @notice using safe math for uints
    using SafeMath for uint256;

    /// @notice using Strings for uints conversion (tokenId)
    using Strings for uint256;

    /// @notice using Address for addresses extended functionality
    using Address for address;

    /// @notice using a counter to increment next Id to be minted
    using Counters for Counters.Counter;

    /// @notice Mapping minted tokens by address
    mapping(address => uint256) private _minted;

    /// @notice tokenIds to supply mapping
    mapping(uint256 => uint256) public tokenMaxSupplies;

    /// @notice The rate of minting per phase
    uint256 public mintPrice;

    /// @notice max amount of nfts that can be minted per wallet address
    uint64 private _mintsPerAddressLimit;

    /// @notice token id to be minted next
    Counters.Counter private _tokenIdTracker;

    /// @notice max tokenId that can be minted
    uint256 public maxTokenId;

    /// @notice public metadata locked flag
    bool public locked;

    /// @notice address owner
    address public owner;

    /// @notice Token name
    string private _name;

    /// @notice Token symbol
    string private _symbol;

    /// @notice Allowed mint bool
    bool private _allowedMint;

    /// @notice Minting events definition
    event AdminMinted(
        address indexed to,
        uint256 indexed tokenId,
        uint256 quantity
    );
    event Minted(address indexed to, uint256 indexed tokenId, uint256 quantity);

    /// @notice metadata not locked modifier
    modifier notLocked() {
        require(!locked, "dEvoting NFT: Metadata URIs are locked");
        _;
    }

    /// @notice only owner modifier
    modifier onlyOwner() {
        require(msg.sender == owner, "dEvoting NFT: only owner");
        _;
    }

    /// @notice only owner modifier
    modifier allowedMint() {
        require(_allowedMint == true, "dEvoting NFT: public mint not allowed");
        _;
    }

    /**
     * @notice constructor
     * @param name_ the name of the Contract
     * @param symbol_ the token symbol
     * @param uri_ token metadata base uri
     **/
    constructor(
        string memory name_,
        string memory symbol_,
        string memory uri_,
        uint256[] memory tokenIds_,
        uint256[] memory tokenSupplies_
    ) ERC1155(uri_) {
        owner = msg.sender;
        _name = name_;
        _symbol = symbol_;
        _initialAddTokens(tokenIds_, tokenSupplies_);
        _mintsPerAddressLimit = 1;
    }

    /// @notice setting starting token id to 1
    function _startTokenId() internal pure virtual returns (uint256) {
        return 0;
    }

    ///@notice returns name of token
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /// @notice returns symbol of token
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @notice changes the minting cost
     * @param mintCost new minting cost
     **/
    function changeMintCost(uint256 mintCost) public onlyOwner {
        require(
            mintCost != mintPrice,
            "dEvoting NFT: mint Cost cannot be same as previous"
        );
        mintPrice = mintCost;
    }

    /**
     * @notice setting token URI
     * @param uri_ new URI
     */
    function setURI(string memory uri_) public onlyOwner {
        require(
            keccak256(abi.encodePacked(super.uri(0))) !=
                keccak256(abi.encodePacked(uri_)),
            "ERROR: URI same as previous"
        );
        _setURI(uri_);
    }

    /**
     * @notice return existing URI
     * @param id id of the token
     */
    function uri(uint256 id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(exists(id), "dEvoting NFT: Nonexistent token");
        return string(abi.encodePacked(super.uri(0), id.toString(), ".json"));
    }

    /**
     * @notice nextId to mint
     **/
    function nextId() internal view returns (uint256) {
        return _tokenIdTracker.current();
    }

    /// @notice pausing the contract minting and token transfer
    function pause() public virtual onlyOwner {
        _pause();
    }

    /// @notice unpausing the contract minting and token transfer
    function unpause() public virtual onlyOwner {
        _unpause();
    }

    function allowPublicMint(uint256 _mintCost, uint64 mintsPerAddressLimit)
        public
        onlyOwner
    {
        _allowedMint = true;
        mintPrice = _mintCost;
        _mintsPerAddressLimit = mintsPerAddressLimit;
    }

    /**
     * @notice burn 1 token
     * @param from addres of the owner of the token
     * @param id id of the token
     * @param amount amount to burn
     */
    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) public {
        _burn(from, id, amount);
    }

    /**
     * @notice burn a batch of tokens
     * @param from addres of the owner of the token
     * @param ids id of the token
     * @param amounts amount to burn
     */
    function burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public {
        _burnBatch(from, ids, amounts);
    }

    /**
     * @notice a function for admins to mint cost-free
     * @param to the address to send the minted token to
     * @param amount amount of tokens to mint
     **/
    function adminMint(
        address to,
        uint256 id,
        uint256 amount
    ) external whenNotPaused onlyOwner {
        require(to != address(0), "dEvoting NFT: Address cannot be 0");

        limitNotExceeded(id, amount);

        checkMintLimit(_msgSender(), amount);

        _mint(to, id, amount, "");

        _minted[to] = amount;

        emit AdminMinted(to, id, amount);
    }

    /**
     * @notice the public/presale minting function
     * @param to the address to send the minted token to
     * @param id id of the token to mint
     * @param amount quantity of tokens to mint
     **/
    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) public payable allowedMint {
        uint256 received = msg.value;

        require(to != address(0), "dEvoting NFT: Address cannot be 0");
        require(
            received == mintPrice.mul(amount),
            "dEvoting NFT: Ether sent mismatch with mint price"
        );

        limitNotExceeded(id, amount);

        checkMintLimit(_msgSender(), amount);

        _mint(to, id, amount, "");

        _minted[to] = amount;

        emit Minted(to, id, amount);
    }

    /**
     * @notice the public minting function -- requires 1 ether sent
     * @param to the address to send the minted token to
     * @param ids ids of the minted tokens
     * @param amounts quantity of tokens to mint
     **/
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public payable allowedMint {
        uint256 received = msg.value;
        uint256 amount = 0;

        require(to != address(0), "dEvoting NFT: Address cannot be 0");

        for (uint256 i = 0; i < amounts.length; i++) {
            limitNotExceeded(ids[i], amounts[i]);
            amount += amounts[i];
        }

        require(
            received == mintPrice.mul(amount),
            "dEvoting NFT: Ether sent mismatch with mint price"
        );

        checkMintLimit(_msgSender(), amount);

        _mintBatch(to, ids, amounts, "");

        for (uint256 i = 0; i < amounts.length; i++) {
            _tokenIdTracker.increment();
            _minted[to] = amount;
            emit Minted(to, ids[i], amounts[i]);
        }
    }

    /**
     * @notice transfer batch of tokens
     * @param from address to transfer from
     * @param to address to transfer to
     * @param ids ids of the token transfered
     * @param amounts amount of token to transfer
     * @param data data to pass while transfer
     */
    function batchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public allowedMint {
        safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @notice transfer token
     * @param from address to transfer from
     * @param to address to transfer to
     * @param id id of the token transfered
     * @param amount amount of token to transfer
     * @param data data to pass while transfer
     */
    function transferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public allowedMint {
        safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @notice the public function for checking if more tokens can be minted
     * @param id id of the token
     * @param amount amount of tokens being minted
     **/
    function limitNotExceeded(uint256 id, uint256 amount)
        public
        view
        returns (bool)
    {
        if (tokenMaxSupplies[id] > 0) {
            require(
                totalSupply(id).add(amount) <= tokenMaxSupplies[id],
                "dEvoting NFT: ID supply exceeded"
            );
        } else {
            require(!exists(id), "");
            require(
                amount == 1 && nextId() <= maxTokenId,
                "dEvoting NFT: NFT supply exceeded"
            );
        }
        return true;
    }

    /**
     * @notice checks if an address reached limit per wallet
     * @param minter address user minting nft
     * @param amount amount of tokens being minted
     **/
    function checkMintLimit(address minter, uint256 amount)
        public
        view
        returns (bool)
    {
        require(
            _minted[minter].add(amount) <= _mintsPerAddressLimit,
            "dEvoting NFT: max NFT mints per address exceeded"
        );
        return true;
    }

    /**
     * @notice add initial token ids with their respective supplies
     * @param tokenIds_ list of token ids to be added
     * @param tokenSupplies_ supply of token id
     **/
    function _initialAddTokens(
        uint256[] memory tokenIds_,
        uint256[] memory tokenSupplies_
    ) private {
        require(
            tokenIds_.length == tokenSupplies_.length,
            "dEvoting NFT: IDs/Supply arity mismatch"
        );
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            tokenMaxSupplies[tokenIds_[i]] = tokenSupplies_[i];
        }
    }

    /**
     * @notice add new token id with its respective supply
     * @param tokenIds_ list of token ids to be added
     * @param tokenSupplies_ supply of token id
     **/
    function addTokensAndChangeMaxSupply(
        uint256[] memory tokenIds_,
        uint256[] memory tokenSupplies_,
        uint256 maxTokenId_
    ) public onlyOwner {
        require(
            tokenIds_.length == tokenSupplies_.length,
            "dEvoting NFT: IDs/Supply arity mismatch"
        );
        require(
            maxTokenId + tokenIds_.length <= maxTokenId_,
            "dEvoting NFT: tokens added mismatch maxSupply"
        );
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            require(
                !exists(tokenIds_[i]),
                "dEvoting NFT: token ID already exists"
            );
            tokenMaxSupplies[tokenIds_[i]] = tokenSupplies_[i];
        }
        maxTokenId = maxTokenId_;
    }

    /**
     * @notice before token transfer hook override
     * @param operator address of the operator
     * @param from address to send tokens from
     * @param to address to send tokens to
     * @param ids ids of the tokens to send
     * @param amounts amount of each token
     * @param data data to pass while sending
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        require(!paused(), "dEvoting NFT: token transfer while paused");
        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _minted[to] += _minted[to].add(amounts[i]);
            }
        }
    }
}
