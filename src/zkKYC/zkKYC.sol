// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IZkKYC.sol";

/**
 * @title ZK-KYC Implementation
 * @notice Soulbound NFT для KYC-верификации с zk-SNARKs
 * @dev Наследует ERC721 с модификациями для Soulbound токенов
 */
contract ZkKYC is ERC721, IZkKYC {
    address public immutable regulator;
    uint256 private _tokenIdCounter;

    struct KYCRecord {
        bytes2 countryCode;
        uint8 gender; // 0 - male, 1 - female
        bool isCleanCriminalRecord;
        uint256 verifiedAt;
        bool isValid;
    }

    mapping(address => uint256) public userToTokenId;
    mapping(uint256 => KYCRecord) public tokenData;

    modifier onlyRegulator() {
        require(msg.sender == regulator, "Only regulator");
        _;
    }

    constructor(address _regulator) ERC721("zkKYC", "zkKYC") {
        regulator = _regulator;
    }

    /// @inheritdoc IZkKYC
    function verifyKYC(
        address user,
        bytes calldata ageProof,
        bytes calldata countryProof,
        bytes calldata additionalData
    ) external onlyRegulator {
        // В реальной реализации здесь должна быть верификация zk-пруфов
        _verifyProofs(ageProof, countryProof);

        uint256 tokenId = ++_tokenIdCounter;
        (bytes2 country, uint8 gender, bool isClean) = _decodeAdditionalData(additionalData);

        _safeMint(user, tokenId);
        userToTokenId[user] = tokenId;
        
        tokenData[tokenId] = KYCRecord({
            countryCode: country,
            gender: gender,
            isCleanCriminalRecord: isClean,
            verifiedAt: block.timestamp,
            isValid: true
        });

        emit KYCVerified(user, country);
    }

    /// @inheritdoc IZkKYC
    function revokeKYC(address user, uint8 reason) external onlyRegulator {
        uint256 tokenId = userToTokenId[user];
        require(tokenId != 0, "User not verified");

        tokenData[tokenId].isValid = false;
        _burn(tokenId);

        emit KYCRevoked(user, reason);
    }

    /// @inheritdoc IZkKYC
    function checkKYC(address user) external view returns (bool isValid, bytes2 countryCode) {
        uint256 tokenId = userToTokenId[user];
        if (tokenId == 0) return (false, 0x0000);
        
        KYCRecord storage record = tokenData[tokenId];
        return (record.isValid, record.countryCode);
    }

    // Soulbound логика - запрет трансферов
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        require(to == address(0) || auth == regulator, "Transfers forbidden");
        return super._update(to, tokenId, auth);
    }

    // Внутренние функции
    function _verifyProofs(bytes calldata ageProof, bytes calldata countryProof) private pure {
        // Здесь должна быть реальная верификация через zk-SNARK верификатор
        require(ageProof.length > 0 && countryProof.length > 0, "Invalid proofs");
    }

    function _decodeAdditionalData(bytes calldata data) private pure returns (bytes2, uint8, bool) {
        return (bytes2(data[0:2]), uint8(data[2]), data[3] > 0);
    }
}